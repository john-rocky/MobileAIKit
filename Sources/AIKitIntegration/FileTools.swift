import Foundation
import AIKit

public enum FileTools {
    public static func readTextFileTool(
        root: URL? = nil,
        maxCharacters: Int = 200_000
    ) -> any Tool {
        let spec = ToolSpec(
            name: "read_text_file",
            description: "Read a UTF-8 text file from disk and return its contents.",
            parameters: .object(
                properties: [
                    "path": .string(description: "File path or absolute URL."),
                    "max_bytes": .integer(minimum: 1)
                ],
                required: ["path"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let path: String; let max_bytes: Int? }
        struct Out: Encodable { let text: String; let truncated: Bool }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let url: URL
            if let root {
                url = root.appendingPathComponent(args.path)
            } else {
                url = URL(fileURLWithPath: args.path)
            }
            let data = try Data(contentsOf: url)
            let full = String(decoding: data, as: UTF8.self)
            let limit = min(args.max_bytes ?? maxCharacters, maxCharacters)
            if full.count > limit {
                let trimmed = String(full.prefix(limit))
                return Out(text: trimmed, truncated: true)
            }
            return Out(text: full, truncated: false)
        }
    }

    public static func listDirectoryTool(root: URL? = nil) -> any Tool {
        let spec = ToolSpec(
            name: "list_directory",
            description: "List files in a directory.",
            parameters: .object(
                properties: ["path": .string()],
                required: ["path"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let path: String }
        struct Entry: Encodable { let name: String; let isDirectory: Bool; let size: Int64? }
        return TypedTool(spec: spec) { (args: Args) async throws -> [Entry] in
            let url: URL
            if let root {
                url = root.appendingPathComponent(args.path)
            } else {
                url = URL(fileURLWithPath: args.path)
            }
            let items = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]
            )
            return items.map { u in
                let values = try? u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                return Entry(
                    name: u.lastPathComponent,
                    isDirectory: values?.isDirectory ?? false,
                    size: values?.fileSize.map { Int64($0) }
                )
            }
        }
    }
}
