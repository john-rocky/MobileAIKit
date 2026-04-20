import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIStructuredResultView<T: Decodable & Sendable, Body: View>: View {
    public let backend: any AIBackend
    public let schema: JSONSchema
    public let type: T.Type
    public let instruction: String
    public let input: String
    public let content: (T) -> Body

    @State private var result: T?
    @State private var error: String?
    @State private var isLoading: Bool = false

    public init(
        backend: any AIBackend,
        schema: JSONSchema,
        type: T.Type,
        instruction: String,
        input: String,
        @ViewBuilder content: @escaping (T) -> Body
    ) {
        self.backend = backend
        self.schema = schema
        self.type = type
        self.instruction = instruction
        self.input = input
        self.content = content
    }

    public var body: some View {
        Group {
            if let result {
                content(result)
            } else if let error {
                Text(error).foregroundStyle(.red)
            } else if isLoading {
                ProgressView()
            } else {
                Color.clear
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let value = try await AIKit.extract(type, from: input, schema: schema, instruction: instruction, backend: backend)
            result = value
        } catch {
            self.error = error.localizedDescription
        }
    }
}
