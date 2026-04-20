import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIStreamingTextView: View {
    @State private var text: String = ""
    @State private var error: String?
    @State private var finished: Bool = false
    @State private var task: Task<Void, Never>?

    let stream: () -> AsyncThrowingStream<GenerationChunk, Error>
    let onFinish: ((String) -> Void)?

    public init(
        stream: @escaping () -> AsyncThrowingStream<GenerationChunk, Error>,
        onFinish: ((String) -> Void)? = nil
    ) {
        self.stream = stream
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !finished {
                ProgressView().controlSize(.small)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding()
        .task {
            task?.cancel()
            task = Task {
                do {
                    for try await chunk in stream() {
                        text += chunk.delta
                    }
                    finished = true
                    onFinish?(text)
                } catch {
                    self.error = error.localizedDescription
                    finished = true
                }
            }
        }
        .onDisappear { task?.cancel() }
    }
}
