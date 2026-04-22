import Foundation
import AIKit

/// Prompt-based tool-calling bridge for `CoreMLLLMBackend`.
///
/// The on-device CoreML-LLM runtime has no native tool-calling support, so we
/// splice a small system prompt describing the available tools + a canonical
/// JSON response format, then parse the model's text output back into
/// `ToolCall` values. ChatSession then executes them as if the backend had
/// returned native tool calls.
///
/// Response contract we ask the model to follow:
/// ```
/// {"tool_calls":[{"name":"<toolName>","arguments":{ …tool-specific JSON… }}]}
/// ```
/// When no tool is needed the model replies with plain text.
enum ToolPromptInjector {

    /// Prepend a tool-instruction system message, if any tools are provided.
    static func inject(tools: [ToolSpec], into messages: [Message]) -> [Message] {
        guard !tools.isEmpty else { return messages }
        let instruction = buildInstruction(for: tools)
        // If the first message is already a system prompt, augment it;
        // otherwise push a new system message to the front.
        if let first = messages.first, first.role == .system {
            let merged = Message.system(first.content + "\n\n" + instruction)
            return [merged] + Array(messages.dropFirst())
        } else {
            return [Message.system(instruction)] + messages
        }
    }

    /// Split the model output into user-visible text + any parsed tool calls.
    /// If the model returned a `{"tool_calls":[…]}` JSON object (optionally
    /// wrapped in code fences or prose), the text is stripped so only the
    /// parsed calls remain; otherwise the raw output is returned unchanged.
    static func parse(output: String, tools: [ToolSpec]) -> (text: String, toolCalls: [ToolCall]) {
        guard !tools.isEmpty else { return (output, []) }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonSubstring = extractJSONObject(from: trimmed) else {
            return (output, [])
        }
        guard let data = jsonSubstring.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let callsArray = obj["tool_calls"] as? [[String: Any]] else {
            return (output, [])
        }
        let allowed = Set(tools.map(\.name))
        var parsed: [ToolCall] = []
        for (i, entry) in callsArray.enumerated() {
            guard let name = entry["name"] as? String, allowed.contains(name) else { continue }
            let argsString: String
            if let argsObj = entry["arguments"] {
                if let s = argsObj as? String {
                    argsString = s
                } else if let argsData = try? JSONSerialization.data(withJSONObject: argsObj, options: [.sortedKeys]),
                          let s = String(data: argsData, encoding: .utf8) {
                    argsString = s
                } else {
                    argsString = "{}"
                }
            } else {
                argsString = "{}"
            }
            let id = (entry["id"] as? String) ?? "call_\(i)"
            parsed.append(ToolCall(id: id, name: name, arguments: argsString))
        }
        if parsed.isEmpty { return (output, []) }
        // Strip the JSON block from the user-facing text.
        let remainingText: String
        if let range = output.range(of: jsonSubstring) {
            var s = output
            s.removeSubrange(range)
            remainingText = s.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            remainingText = ""
        }
        return (remainingText, parsed)
    }

    // MARK: - Helpers

    private static func buildInstruction(for tools: [ToolSpec]) -> String {
        let list: [[String: Any]] = tools.map { spec in
            [
                "name": spec.name,
                "description": spec.description,
                "parameters": spec.parameters.toAny()
            ]
        }
        let listJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: list, options: [.prettyPrinted, .sortedKeys]),
           let s = String(data: data, encoding: .utf8) {
            listJSON = s
        } else {
            listJSON = "[]"
        }
        return """
        You have access to the following tools. Use them when the user's request \
        cannot be answered from your own knowledge alone (e.g. needs live data, \
        device state, or a side-effecting action).

        Tools:
        \(listJSON)

        When you decide to call one or more tools, respond with ONE JSON object \
        and nothing else, in this exact shape:

        {"tool_calls":[{"name":"<tool name>","arguments":{ /* JSON arguments matching the tool's parameters schema */ }}]}

        You may call multiple tools in the same turn by adding more items to the \
        "tool_calls" array. After you receive the tool results, you will be \
        asked again and can either call more tools or produce a final plain-text \
        answer for the user. If no tool is needed, just answer in plain text — \
        do NOT emit the JSON object in that case.
        """
    }

    /// Locate the outermost balanced `{ … }` block in `text`, preferring one
    /// that contains the literal `"tool_calls"` key. Tolerates code fences /
    /// leading or trailing prose the model may add despite instructions.
    private static func extractJSONObject(from text: String) -> String? {
        // Prefer a fenced ```json { … } ``` block if present.
        if let fencedRange = text.range(of: #"```(?:json)?\s*(\{[\s\S]*?\})\s*```"#, options: .regularExpression) {
            let fenced = String(text[fencedRange])
            if let inner = fenced.range(of: #"\{[\s\S]*\}"#, options: .regularExpression) {
                let candidate = String(fenced[inner])
                if candidate.contains("tool_calls") { return candidate }
            }
        }
        // Otherwise scan for the first '{' whose balanced match contains
        // "tool_calls" and return that block.
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            if chars[i] == "{" {
                if let end = balancedClose(chars: chars, openAt: i) {
                    let candidate = String(chars[i...end])
                    if candidate.contains("tool_calls") { return candidate }
                    i = end + 1
                    continue
                }
            }
            i += 1
        }
        return nil
    }

    private static func balancedClose(chars: [Character], openAt start: Int) -> Int? {
        var depth = 0
        var inString = false
        var escaped = false
        var i = start
        while i < chars.count {
            let c = chars[i]
            if escaped { escaped = false; i += 1; continue }
            if inString {
                if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
            } else {
                if c == "\"" { inString = true }
                else if c == "{" { depth += 1 }
                else if c == "}" {
                    depth -= 1
                    if depth == 0 { return i }
                }
            }
            i += 1
        }
        return nil
    }
}
