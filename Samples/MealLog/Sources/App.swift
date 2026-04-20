import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct MealLogApp: App {
    @State private var backend: (any AIBackend)?
    @State private var store: MealStore?
    @State private var error: String?

    var body: some Scene {
        WindowGroup {
            if let backend, let store {
                RootView(store: store, backend: backend)
            } else if let error {
                VStack {
                    Text("Setup failed").font(.headline)
                    Text(error).foregroundStyle(.secondary).padding()
                    Button("Retry") { Task { await boot() } }.buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle.fill").font(.system(size: 60)).foregroundStyle(.tint)
                    Text("Preparing Gemma 4…"); ProgressView()
                }.task { await boot() }
            }
        }
    }

    @MainActor
    private func boot() async {
        do {
            let s = try MealStore()
            let b = CoreMLLLMBackend(model: .gemma4e2b)
            try await b.load()
            self.store = s
            self.backend = b
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct RootView: View {
    @Bindable var store: MealStore
    let backend: any AIBackend

    var body: some View {
        TabView {
            NavigationStack { HistoryView(store: store, backend: backend) }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            NavigationStack { LogMealView(store: store, backend: backend) }
                .tabItem { Label("Log", systemImage: "camera.fill") }
            NavigationStack { AskView(store: store, backend: backend) }
                .tabItem { Label("Ask", systemImage: "sparkles") }
        }
    }
}
