import SwiftUI
import AIKit
import AIKitCoreMLLLM

@main
struct MomentsApp: App {
    private let backend = CoreMLLLMBackend(model: .gemma4e2b)
    @State private var storeResult: Result<MomentStore, Error> = Result { try MomentStore() }

    var body: some Scene {
        WindowGroup {
            CoreMLModelLoaderView(
                backend: backend,
                appName: "Moments",
                appIcon: "sparkles.tv"
            ) {
                switch storeResult {
                case .success(let store):
                    RootView(store: store, backend: backend)
                case .failure(let error):
                    StoreErrorView(message: error.localizedDescription) {
                        storeResult = Result { try MomentStore() }
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
