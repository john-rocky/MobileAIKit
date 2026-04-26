import SwiftUI
import AIKit
import AIKitUI
import AIKitAgent

/// The main agent surface. Boots an ``AIAgent`` pre-loaded with every
/// on-device tool pack (calendar, contacts, weather, maps, HealthKit,
/// camera, photo picker, scanner, web search, PDF, location, …) plus the
/// four app-specific tools declared in ``AppTools``.
///
/// The row of suggestion chips at the top fires real prompts into the agent
/// so you can see each capability light up in one tap.
struct ContentView: View {
    let backend: any AIBackend

    @State private var agent: AIAgent?
    @State private var todos = TodoStore()

    var body: some View {
        NavigationStack {
            Group {
                if let agent {
                    VStack(spacing: 0) {
                        SuggestionBar { prompt in
                            Task { try? await agent.send(prompt) }
                        }
                        Divider()
                        AIAgentView(agent: agent, additionalTools: AppTools.all(todos: todos))
                    }
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Registering tools…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Agent Playground")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let agent {
                        Menu {
                            Button("Reset conversation", role: .destructive) {
                                agent.reset()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .task {
            if agent == nil {
                agent = await AgentKit.build(
                    backend: backend,
                    options: .init(
                        systemPrompt: """
                        You are an on-device demo assistant. Tool calls are routed through a dedicated function-calling model; chat / vision / summary turns run on Gemma. After a tool result comes back, reply in 1–2 sentences summarising what happened.
                        """
                    )
                )
            }
        }
    }
}

// MARK: - Suggestion chips

private struct SuggestionBar: View {
    let onTap: (String) -> Void

    private let prompts: [(String, String)] = [
        ("sun.max", "What's the weather like where I am?"),
        ("calendar", "What's on my calendar today?"),
        ("magnifyingglass", "Search the web for the latest Swift news."),
        ("camera", "Take a photo and describe what you see."),
        ("mappin.and.ellipse", "Find three coffee shops near me."),
        ("checklist", "Add \"buy milk\" to my todos."),
        ("list.bullet.rectangle", "Show my open todos."),
        ("die.face.5", "Roll 2 six-sided dice."),
        ("figure.walk", "How many steps did I take today?"),
        ("person.crop.circle", "Find my contact named Alex.")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(prompts, id: \.1) { icon, text in
                    Button { onTap(text) } label: {
                        Label(text, systemImage: icon)
                            .font(.footnote)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.quaternary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
