import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct MealLogApp: App {
    private let backend = CoreMLLLMBackend(model: .gemma4e2b)
    @State private var storeResult: Result<MealStore, Error> = Result { try MealStore() }

    var body: some Scene {
        WindowGroup {
            CoreMLModelLoaderView(
                backend: backend,
                appName: "MealLog",
                appIcon: "fork.knife.circle.fill"
            ) {
                switch storeResult {
                case .success(let store):
                    RootView(store: store, backend: backend)
                case .failure(let error):
                    StoreErrorView(message: error.localizedDescription) {
                        storeResult = Result { try MealStore() }
                    }
                }
            }
        }
    }
}

private struct StoreErrorView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Couldn't open local store").font(.headline)
            Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry", action: retry).buttonStyle(.borderedProminent)
        }
        .padding()
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
