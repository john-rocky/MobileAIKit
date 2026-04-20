import SwiftUI
import AIKit

struct TimelineView: View {
    @Bindable var store: MomentStore
    let backend: any AIBackend
    @State private var query: String = ""
    @State private var filtered: [Moment]?
    @State private var isSearching = false

    var visible: [Moment] { filtered ?? store.moments }

    var body: some View {
        List {
            if store.moments.isEmpty {
                ContentUnavailableView {
                    Label("No moments yet", systemImage: "sparkles")
                } description: {
                    Text("Capture your first one from the + tab.")
                }
            }
            ForEach(visible) { moment in
                NavigationLink {
                    DetailView(store: store, backend: backend, momentId: moment.id)
                } label: {
                    MomentRow(store: store, moment: moment)
                }
            }
            .onDelete { indexSet in
                Task { await delete(at: indexSet) }
            }
        }
        .navigationTitle("Moments")
        .searchable(text: $query, prompt: "Search your life")
        .onSubmit(of: .search) { Task { await runSearch() } }
        .onChange(of: query) { _, newValue in
            if newValue.isEmpty { filtered = nil }
        }
    }

    @MainActor
    private func runSearch() async {
        guard !query.isEmpty else { filtered = nil; return }
        isSearching = true
        defer { isSearching = false }
        filtered = (try? await store.search(query)) ?? []
    }

    @MainActor
    private func delete(at offsets: IndexSet) async {
        for idx in offsets {
            try? await store.delete(visible[idx])
        }
        await runSearch()
    }
}

struct MomentRow: View {
    let store: MomentStore
    let moment: Moment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(moment.title).font(.headline).lineLimit(1)
                Text(moment.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                if !moment.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(moment.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.tint.opacity(0.15), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    var thumbnail: some View {
        if let url = store.imageURL(for: moment),
           let data = try? Data(contentsOf: url),
           let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            Image(systemName: "sparkles")
                .font(.title2)
                .frame(width: 56, height: 56)
                .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
