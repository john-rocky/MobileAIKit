import Foundation

public struct ChatTemplate: Sendable, Hashable {
    public enum Style: String, Sendable, Hashable, Codable {
        case llama3
        case llama2
        case chatML
        case gemma
        case mistral
        case phi3
        case qwen
        case custom
    }

    public let style: Style
    public let systemWrapper: (String) -> String
    public let userWrapper: (String) -> String
    public let assistantWrapper: (String) -> String
    public let toolWrapper: (String, String) -> String
    public let stopSequences: [String]

    public static func == (lhs: ChatTemplate, rhs: ChatTemplate) -> Bool {
        lhs.style == rhs.style
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(style) }

    public init(
        style: Style,
        systemWrapper: @escaping (String) -> String,
        userWrapper: @escaping (String) -> String,
        assistantWrapper: @escaping (String) -> String,
        toolWrapper: @escaping (String, String) -> String,
        stopSequences: [String]
    ) {
        self.style = style
        self.systemWrapper = systemWrapper
        self.userWrapper = userWrapper
        self.assistantWrapper = assistantWrapper
        self.toolWrapper = toolWrapper
        self.stopSequences = stopSequences
    }

    public func render(_ messages: [Message], addGenerationPrompt: Bool = true) -> String {
        var out = ""
        for m in messages {
            switch m.role {
            case .system:    out += systemWrapper(m.content)
            case .user:      out += userWrapper(m.content)
            case .assistant: out += assistantWrapper(m.content)
            case .tool:      out += toolWrapper(m.name ?? "tool", m.content)
            }
        }
        if addGenerationPrompt {
            out += generationPrompt
        }
        return out
    }

    public var generationPrompt: String {
        switch style {
        case .llama3: return "<|start_header_id|>assistant<|end_header_id|>\n\n"
        case .chatML: return "<|im_start|>assistant\n"
        case .gemma: return "<start_of_turn>model\n"
        case .qwen: return "<|im_start|>assistant\n"
        case .phi3: return "<|assistant|>\n"
        default: return ""
        }
    }

    public static let llama3 = ChatTemplate(
        style: .llama3,
        systemWrapper: { "<|start_header_id|>system<|end_header_id|>\n\n\($0)<|eot_id|>" },
        userWrapper: { "<|start_header_id|>user<|end_header_id|>\n\n\($0)<|eot_id|>" },
        assistantWrapper: { "<|start_header_id|>assistant<|end_header_id|>\n\n\($0)<|eot_id|>" },
        toolWrapper: { _, content in "<|start_header_id|>ipython<|end_header_id|>\n\n\(content)<|eot_id|>" },
        stopSequences: ["<|eot_id|>", "<|end_of_text|>"]
    )

    public static let chatML = ChatTemplate(
        style: .chatML,
        systemWrapper: { "<|im_start|>system\n\($0)<|im_end|>\n" },
        userWrapper: { "<|im_start|>user\n\($0)<|im_end|>\n" },
        assistantWrapper: { "<|im_start|>assistant\n\($0)<|im_end|>\n" },
        toolWrapper: { name, content in "<|im_start|>tool\nname=\(name)\n\(content)<|im_end|>\n" },
        stopSequences: ["<|im_end|>"]
    )

    public static let gemma = ChatTemplate(
        style: .gemma,
        systemWrapper: { "<start_of_turn>user\n\($0)<end_of_turn>\n" },
        userWrapper: { "<start_of_turn>user\n\($0)<end_of_turn>\n" },
        assistantWrapper: { "<start_of_turn>model\n\($0)<end_of_turn>\n" },
        toolWrapper: { _, content in "<start_of_turn>tool\n\(content)<end_of_turn>\n" },
        stopSequences: ["<end_of_turn>"]
    )

    public static let phi3 = ChatTemplate(
        style: .phi3,
        systemWrapper: { "<|system|>\n\($0)<|end|>\n" },
        userWrapper: { "<|user|>\n\($0)<|end|>\n" },
        assistantWrapper: { "<|assistant|>\n\($0)<|end|>\n" },
        toolWrapper: { _, content in "<|tool|>\n\(content)<|end|>\n" },
        stopSequences: ["<|end|>"]
    )

    public static let qwen = ChatTemplate(
        style: .qwen,
        systemWrapper: { "<|im_start|>system\n\($0)<|im_end|>\n" },
        userWrapper: { "<|im_start|>user\n\($0)<|im_end|>\n" },
        assistantWrapper: { "<|im_start|>assistant\n\($0)<|im_end|>\n" },
        toolWrapper: { _, content in "<|im_start|>tool\n\(content)<|im_end|>\n" },
        stopSequences: ["<|im_end|>"]
    )

    public static let mistral = ChatTemplate(
        style: .mistral,
        systemWrapper: { "[INST] <<SYS>>\n\($0)\n<</SYS>>\n\n" },
        userWrapper: { "[INST] \($0) [/INST]" },
        assistantWrapper: { " \($0) " },
        toolWrapper: { _, content in "[TOOL] \(content) [/TOOL]" },
        stopSequences: ["</s>"]
    )

    public static let llama2 = ChatTemplate(
        style: .llama2,
        systemWrapper: { "[INST] <<SYS>>\n\($0)\n<</SYS>>\n\n" },
        userWrapper: { "[INST] \($0) [/INST]" },
        assistantWrapper: { " \($0) </s><s>" },
        toolWrapper: { _, content in "[TOOL]\(content)[/TOOL]" },
        stopSequences: ["</s>"]
    )

    public static func auto(name modelName: String) -> ChatTemplate {
        let n = modelName.lowercased()
        if n.contains("llama-3") || n.contains("llama3") { return .llama3 }
        if n.contains("llama-2") || n.contains("llama2") { return .llama2 }
        if n.contains("gemma") { return .gemma }
        if n.contains("phi-3") || n.contains("phi3") { return .phi3 }
        if n.contains("qwen") { return .qwen }
        if n.contains("mistral") || n.contains("mixtral") { return .mistral }
        return .chatML
    }
}
