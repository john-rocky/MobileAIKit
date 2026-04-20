import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIMemoryInspectorView: View {
    public let memory: any MemoryStoreProtocol
    public var namespace: String = "default"

    @State private var records: [MemoryRecord] = []
    @State private var error: String?

    public init(memory: any MemoryStoreProtocol, namespace: String = "default") {
        self.memory = memory
        self.namespace = namespace
    }

    public var body: some View {
        List {
            ForEach(records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(record.kind.rawValue).font(.caption).foregroundStyle(.tint)
                        Spacer()
                        Text(record.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(record.text).font(.body)
                    if !record.entities.isEmpty {
                        HStack {
                            ForEach(record.entities, id: \.self) { entity in
                                Text(entity).font(.caption2).padding(4).background(.secondary.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { try? await memory.forget(id: record.id); await reload() }
                    } label: { Label("Forget", systemImage: "trash") }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .navigationTitle("Memory")
    }

    private func reload() async {
        do {
            records = try await memory.all(namespace: namespace)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
