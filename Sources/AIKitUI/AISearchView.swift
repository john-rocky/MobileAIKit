import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AISearchView: View {
    public let index: VectorIndex

    @State private var query: String = ""
    @State private var results: [RetrievedDocument] = []
    @State private var isSearching: Bool = false
    @State private var error: String?

    public init(index: VectorIndex) {
        self.index = index
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search the index…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(search)
                Button("Search", action: search)
                    .disabled(isSearching || query.isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            if isSearching { ProgressView() }

            List(results, id: \.chunk.id) { doc in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(doc.source).font(.caption).foregroundStyle(.tint)
                        Spacer()
                        Text(String(format: "%.2f", doc.score)).font(.caption).monospacedDigit()
                    }
                    Text(doc.text).lineLimit(6)
                    HStack {
                        Label(String(format: "vec %.2f", doc.vectorScore), systemImage: "vector.line")
                        Label(String(format: "kw %.2f", doc.keywordScore), systemImage: "text.magnifyingglass")
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let error { Text(error).foregroundStyle(.red) }
        }
    }

    private func search() {
        guard !query.isEmpty else { return }
        isSearching = true
        error = nil
        Task {
            do {
                results = try await index.search(query: query, limit: 20)
            } catch {
                self.error = error.localizedDescription
            }
            isSearching = false
        }
    }
}
