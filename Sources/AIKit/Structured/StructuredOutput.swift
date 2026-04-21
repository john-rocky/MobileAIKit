import Foundation

public struct StructuredDecoder: @unchecked Sendable {
    // @unchecked: JSONDecoder is thread-safe for concurrent .decode() calls,
    // and we never mutate `decoder` or `repairEnabled` after init across actors.
    public var decoder: JSONDecoder
    public var repairEnabled: Bool

    public init(decoder: JSONDecoder = JSONDecoder(), repairEnabled: Bool = true) {
        self.decoder = decoder
        self.repairEnabled = repairEnabled
    }

    public func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        let candidates = Self.extractJSONCandidates(from: text)
        var lastError: Error = AIError.decodingFailed("No JSON found")
        for cand in candidates {
            if let data = cand.data(using: .utf8) {
                do {
                    return try decoder.decode(type, from: data)
                } catch {
                    lastError = error
                }
            }
        }
        if repairEnabled {
            for cand in candidates {
                if let repaired = Self.repair(cand)?.data(using: .utf8) {
                    if let value = try? decoder.decode(type, from: repaired) {
                        return value
                    }
                }
            }
        }
        throw AIError.decodingFailed(lastError.localizedDescription)
    }

    public static func extractJSONCandidates(from text: String) -> [String] {
        var results: [String] = []
        let codeFence = #"```(?:json)?\s*([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: codeFence) {
            let ns = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            for m in matches where m.numberOfRanges >= 2 {
                let inner = ns.substring(with: m.range(at: 1))
                results.append(inner.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        if let extracted = balancedExtract(text, open: "{", close: "}") {
            results.append(extracted)
        }
        if let extracted = balancedExtract(text, open: "[", close: "]") {
            results.append(extracted)
        }
        results.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
        var seen = Set<String>()
        return results.filter { seen.insert($0).inserted && !$0.isEmpty }
    }

    private static func balancedExtract(_ s: String, open: Character, close: Character) -> String? {
        guard let start = s.firstIndex(of: open) else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        var idx = start
        while idx < s.endIndex {
            let c = s[idx]
            if escape { escape = false }
            else if c == "\\" { escape = true }
            else if c == "\"" { inString.toggle() }
            else if !inString {
                if c == open { depth += 1 }
                else if c == close {
                    depth -= 1
                    if depth == 0 {
                        return String(s[start...idx])
                    }
                }
            }
            idx = s.index(after: idx)
        }
        return nil
    }

    static func repair(_ s: String) -> String? {
        var out = s
        out = out.replacingOccurrences(of: "\t", with: " ")
        if let regex = try? NSRegularExpression(pattern: ",\\s*([}\\]])") {
            let ns = out as NSString
            let range = NSRange(location: 0, length: ns.length)
            out = regex.stringByReplacingMatches(in: out, range: range, withTemplate: "$1")
        }
        var depth = 0
        var bracketDepth = 0
        var inString = false
        var escape = false
        for c in out {
            if escape { escape = false; continue }
            if c == "\\" { escape = true; continue }
            if c == "\"" { inString.toggle(); continue }
            if inString { continue }
            if c == "{" { depth += 1 }
            else if c == "}" { depth -= 1 }
            else if c == "[" { bracketDepth += 1 }
            else if c == "]" { bracketDepth -= 1 }
        }
        if inString { out += "\"" }
        out += String(repeating: "]", count: max(0, bracketDepth))
        out += String(repeating: "}", count: max(0, depth))
        return out
    }
}

public protocol PartialFrom {
    init()
}

public struct PartialStructuredParser<T: Decodable> {
    public let decoder: StructuredDecoder

    public init(decoder: StructuredDecoder = .init()) {
        self.decoder = decoder
    }

    public func tryDecode(buffer: String) -> T? {
        try? decoder.decode(T.self, from: buffer)
    }
}
