import SwiftUI
import AIKit
import AIKitUI
import AIKitSpeech
import AIKitIntegration

struct HomeView: View {
    let backend: any AIBackend

    var body: some View {
        List {
            Section("Chat") {
                NavigationLink("Streaming chat") {
                    AIChatView(session: ChatSession(backend: backend, systemPrompt: "Be concise."))
                        .navigationTitle("Chat")
                }
                NavigationLink("Prompt playground") {
                    AIPromptPlaygroundView(backend: backend).navigationTitle("Playground")
                }
            }

            Section("RAG") {
                NavigationLink("Document Q&A") {
                    RAGDemoView(backend: backend)
                }
                NavigationLink("Browse-and-ask") {
                    BrowseAndAskView(backend: backend)
                }
            }

            Section("Vision") {
                NavigationLink("Camera assistant") {
                    AICameraAssistantView(backend: backend)
                        .navigationTitle("Camera")
                }
                NavigationLink("OCR extractor") {
                    StateWrapOCR().navigationTitle("OCR")
                }
            }

            Section("Voice") {
                NavigationLink("Voice assistant") {
                    VoiceDemoView(backend: backend)
                }
            }

            Section("Tools & agents") {
                NavigationLink("Web search agent") {
                    WebSearchAgentView(backend: backend)
                }
            }

            Section("Performance & settings") {
                NavigationLink("Benchmark") {
                    AIBenchmarkView(backend: backend).navigationTitle("Benchmark")
                }
                NavigationLink("Settings") {
                    AISettingsView()
                }
            }
        }
        .navigationTitle("AIKit Demo")
    }
}

struct StateWrapOCR: View {
    @State var attachments: [Attachment] = []
    var body: some View { AIOCRExtractionView(attachments: $attachments) }
}
