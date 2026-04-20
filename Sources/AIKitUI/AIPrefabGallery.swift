import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIPrefabGallery: View {
    public let backend: any AIBackend
    public let index: VectorIndex?
    public let memory: (any MemoryStoreProtocol)?
    public let telemetry: Telemetry?

    public init(
        backend: any AIBackend,
        index: VectorIndex? = nil,
        memory: (any MemoryStoreProtocol)? = nil,
        telemetry: Telemetry? = nil
    ) {
        self.backend = backend
        self.index = index
        self.memory = memory
        self.telemetry = telemetry
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Chat") {
                    NavigationLink("AIChatView") {
                        AIChatView(session: ChatSession(backend: backend))
                    }
                    NavigationLink("AIPromptPlaygroundView") {
                        AIPromptPlaygroundView(backend: backend)
                    }
                }
                Section("Camera / OCR") {
                    NavigationLink("AICameraAssistantView") { AICameraAssistantView(backend: backend) }
                    NavigationLink("AIOCRExtractionView") {
                        StateWrapOCR()
                    }
                }
                if let index {
                    Section("Search / RAG") {
                        NavigationLink("AISearchView") { AISearchView(index: index) }
                        NavigationLink("AIDocumentQAView") { AIDocumentQAView(backend: backend, index: index) }
                    }
                }
                if let memory {
                    Section("Memory") {
                        NavigationLink("AIMemoryInspectorView") { AIMemoryInspectorView(memory: memory) }
                    }
                }
                if let telemetry {
                    Section("Telemetry") {
                        NavigationLink("AIDebugPanelView") { AIDebugPanelView(telemetry: telemetry) }
                        NavigationLink("AIBenchmarkView") { AIBenchmarkView(backend: backend) }
                    }
                }
                Section("Settings") {
                    NavigationLink("AISettingsView") { AISettingsView() }
                }
            }
            .navigationTitle("AIKit Gallery")
        }
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
private struct StateWrapOCR: View {
    @State var atts: [Attachment] = []
    var body: some View { AIOCRExtractionView(attachments: $atts) }
}
