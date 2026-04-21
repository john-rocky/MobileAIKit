import Foundation
import SwiftUI
import AIKit
import AIKitAgent

// MARK: - 1. One-line view-attached agent

/// Drop-in SwiftUI view. The user can ask the model to open the camera, read the
/// calendar, search the web, describe a photo, etc. Every available on-device
/// tool is auto-registered, and UI-presenting tools (camera, scanner, location
/// picker, share sheet) are routed through the enclosing view.
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
struct AgentHomeScreen: View {
    let backend: any AIBackend
    var body: some View {
        AIAgentDefaultView(backend: backend)
    }
}

// MARK: - 2. Adding a custom app-specific tool

enum AppTools {
    static func addToCartTool(cart: ShoppingCart) -> any Tool {
        let spec = ToolSpec(
            name: "add_to_cart",
            description: "Add a product to the user's shopping cart.",
            parameters: .object(
                properties: [
                    "sku": .string(),
                    "quantity": .integer(minimum: 1, maximum: 99)
                ],
                required: ["sku"]
            ),
            requiresApproval: true,
            sideEffectFree: false
        )
        struct Args: Decodable { let sku: String; let quantity: Int? }
        struct Out: Encodable { let added: Bool; let total: Int }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let count = await cart.add(sku: args.sku, quantity: args.quantity ?? 1)
            return Out(added: true, total: count)
        }
    }
}

actor ShoppingCart {
    private var items: [String: Int] = [:]
    func add(sku: String, quantity: Int) -> Int {
        items[sku, default: 0] += quantity
        return items.values.reduce(0, +)
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
struct ShoppingScreen: View {
    let backend: any AIBackend
    let cart = ShoppingCart()
    var body: some View {
        AIAgentDefaultView(
            backend: backend,
            extraTools: [AppTools.addToCartTool(cart: cart)]
        )
    }
}

// MARK: - 3. Headless agent (no UI) — runs from a Siri shortcut / background task

enum AgentBackgroundJob {
    @MainActor
    static func summarizeTodayAgenda(backend: any AIBackend) async throws -> String {
        let agent = await AgentKit.build(backend: backend)  // NullAgentHost by default
        return try await agent.send("Summarize my meetings today.").content
    }
}

// MARK: - 4. Manual host control (custom chrome around AIAgent)

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
struct CustomChromeAgent: View {
    @State private var agent: AIAgent?
    let backend: any AIBackend

    var body: some View {
        VStack {
            MyCustomHeader()
            if let agent {
                AIAgentView(agent: agent)
            } else {
                ProgressView()
            }
            MyCustomFooter()
        }
        .task {
            if agent == nil {
                agent = await AgentKit.build(backend: backend)
            }
        }
    }
}

private struct MyCustomHeader: View { var body: some View { Text("My app").font(.headline) } }
private struct MyCustomFooter: View { var body: some View { Text("v1.0").font(.caption) } }
