import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIToolExecutionLogView: View {
    public struct Entry: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let call: ToolCall
        public let result: ToolResult
        public let duration: TimeInterval
    }
    public let entries: [Entry]

    public init(entries: [Entry]) { self.entries = entries }

    public var body: some View {
        List(entries) { entry in
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Arguments").font(.caption).foregroundStyle(.secondary)
                    Text(entry.call.arguments).monospaced().textSelection(.enabled)
                    Text("Result").font(.caption).foregroundStyle(.secondary)
                    Text(entry.result.text).monospaced().textSelection(.enabled)
                }
            } label: {
                HStack {
                    Image(systemName: entry.result.isError ? "xmark.octagon.fill" : "checkmark.seal.fill")
                        .foregroundStyle(entry.result.isError ? .red : .green)
                    Text(entry.call.name).font(.headline)
                    Spacer()
                    Text("\(String(format: "%.2fs", entry.duration))").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
