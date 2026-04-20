import Foundation

public indirect enum JSONSchema: Sendable, Hashable, Codable {
    case string(description: String? = nil, enumValues: [String]? = nil, format: String? = nil)
    case integer(description: String? = nil, minimum: Int? = nil, maximum: Int? = nil)
    case number(description: String? = nil, minimum: Double? = nil, maximum: Double? = nil)
    case boolean(description: String? = nil)
    case array(items: JSONSchema, description: String? = nil, minItems: Int? = nil, maxItems: Int? = nil)
    case object(properties: [String: JSONSchema], required: [String], description: String? = nil, additionalProperties: Bool = false)
    case anyOf([JSONSchema])
    case null

    public func toAny() -> [String: Any] {
        switch self {
        case .string(let d, let ev, let f):
            var s: [String: Any] = ["type": "string"]
            if let d { s["description"] = d }
            if let ev { s["enum"] = ev }
            if let f { s["format"] = f }
            return s
        case .integer(let d, let mn, let mx):
            var s: [String: Any] = ["type": "integer"]
            if let d { s["description"] = d }
            if let mn { s["minimum"] = mn }
            if let mx { s["maximum"] = mx }
            return s
        case .number(let d, let mn, let mx):
            var s: [String: Any] = ["type": "number"]
            if let d { s["description"] = d }
            if let mn { s["minimum"] = mn }
            if let mx { s["maximum"] = mx }
            return s
        case .boolean(let d):
            var s: [String: Any] = ["type": "boolean"]
            if let d { s["description"] = d }
            return s
        case .array(let items, let d, let minI, let maxI):
            var s: [String: Any] = ["type": "array", "items": items.toAny()]
            if let d { s["description"] = d }
            if let minI { s["minItems"] = minI }
            if let maxI { s["maxItems"] = maxI }
            return s
        case .object(let props, let req, let d, let addl):
            var p: [String: Any] = [:]
            for (k, v) in props { p[k] = v.toAny() }
            var s: [String: Any] = [
                "type": "object",
                "properties": p,
                "required": req,
                "additionalProperties": addl
            ]
            if let d { s["description"] = d }
            return s
        case .anyOf(let schemas):
            return ["anyOf": schemas.map { $0.toAny() }]
        case .null:
            return ["type": "null"]
        }
    }

    public func jsonData() throws -> Data {
        try JSONSerialization.data(withJSONObject: toAny(), options: [.sortedKeys])
    }
}

public extension JSONSchema {
    static func from<T: Encodable>(_ type: T.Type, sample: T) throws -> JSONSchema {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(sample)
        let obj = try JSONSerialization.jsonObject(with: data)
        return inferSchema(from: obj)
    }

    static func inferSchema(from value: Any) -> JSONSchema {
        if value is NSNull { return .null }
        if let b = value as? Bool { _ = b; return .boolean() }
        if let _ = value as? Int { return .integer() }
        if let _ = value as? Double { return .number() }
        if let _ = value as? String { return .string() }
        if let arr = value as? [Any] {
            let item = arr.first.map { inferSchema(from: $0) } ?? .string()
            return .array(items: item)
        }
        if let dict = value as? [String: Any] {
            var props: [String: JSONSchema] = [:]
            var req: [String] = []
            for (k, v) in dict {
                props[k] = inferSchema(from: v)
                req.append(k)
            }
            return .object(properties: props, required: req)
        }
        return .string()
    }
}
