import SwiftUI
import AIKit

struct RootView: View {
    @Bindable var store: MomentStore
    let backend: any AIBackend

    var body: some View {
        TabView {
            NavigationStack { TimelineView(store: store, backend: backend) }
                .tabItem { Label("Timeline", systemImage: "rectangle.stack") }

            NavigationStack { CaptureView(store: store, backend: backend) }
                .tabItem { Label("Capture", systemImage: "plus.viewfinder") }

            NavigationStack { AskMemoriesView(store: store, backend: backend) }
                .tabItem { Label("Ask", systemImage: "sparkles") }
        }
    }
}
