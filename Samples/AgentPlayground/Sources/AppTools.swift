import Foundation
import AIKit

// MARK: - Shared stores

/// In-memory todo store. A real app would back this with SwiftData / SQLite.
actor TodoStore {
    struct Item: Codable, Identifiable, Sendable {
        var id: UUID = UUID()
        var title: String
        var due: String?
        var done: Bool = false
    }

    private var items: [Item] = []

    func add(title: String, due: String?) -> Item {
        let item = Item(title: title, due: due)
        items.append(item)
        return item
    }

    func list(includeDone: Bool) -> [Item] {
        includeDone ? items : items.filter { !$0.done }
    }

    func complete(idPrefix: String) -> Item? {
        guard let idx = items.firstIndex(where: { $0.id.uuidString.hasPrefix(idPrefix.uppercased()) }) else {
            return nil
        }
        items[idx].done = true
        return items[idx]
    }
}

// MARK: - Tool factory

enum AppTools {
    static func all(todos: TodoStore) -> [any Tool] {
        [
            addTodoTool(todos: todos),
            listTodosTool(todos: todos),
            completeTodoTool(todos: todos),
            rollDiceTool()
        ]
    }

    // MARK: add_todo — stateful, requires approval

    static func addTodoTool(todos: TodoStore) -> any Tool {
        struct Args: Decodable { let title: String; let due: String? }
        struct Out: Encodable { let added: Bool; let id: String; let title: String }
        let spec = ToolSpec(
            name: "add_todo",
            description: "Add an item to the user's in-app todo list. Use this whenever the user asks to remember a task.",
            parameters: .object(
                properties: [
                    "title": .string(description: "Short task description."),
                    "due": .string(description: "Optional due date in natural language, e.g. 'tomorrow 5pm'.")
                ],
                required: ["title"]
            ),
            requiresApproval: true,
            sideEffectFree: false
        )
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let item = await todos.add(title: args.title, due: args.due)
            return Out(added: true, id: String(item.id.uuidString.prefix(8)), title: item.title)
        }
    }

    // MARK: list_todos — side-effect free

    static func listTodosTool(todos: TodoStore) -> any Tool {
        struct Args: Decodable { let includeDone: Bool? }
        struct Row: Encodable { let id: String; let title: String; let due: String?; let done: Bool }
        struct Out: Encodable { let items: [Row] }
        let spec = ToolSpec(
            name: "list_todos",
            description: "List the user's in-app todos. Set includeDone=true to include completed items.",
            parameters: .object(
                properties: [
                    "includeDone": .boolean(description: "Include completed todos.")
                ],
                required: []
            ),
            requiresApproval: false,
            sideEffectFree: true
        )
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let items = await todos.list(includeDone: args.includeDone ?? false)
            return Out(items: items.map {
                Row(id: String($0.id.uuidString.prefix(8)), title: $0.title, due: $0.due, done: $0.done)
            })
        }
    }

    // MARK: complete_todo — stateful, requires approval

    static func completeTodoTool(todos: TodoStore) -> any Tool {
        struct Args: Decodable { let id: String }
        struct Out: Encodable { let completed: Bool; let title: String? }
        let spec = ToolSpec(
            name: "complete_todo",
            description: "Mark a todo as done by its short id (first 8 characters).",
            parameters: .object(
                properties: [
                    "id": .string(description: "The short id returned by add_todo or list_todos.")
                ],
                required: ["id"]
            ),
            requiresApproval: true,
            sideEffectFree: false
        )
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            if let item = await todos.complete(idPrefix: args.id) {
                return Out(completed: true, title: item.title)
            }
            return Out(completed: false, title: nil)
        }
    }

    // MARK: roll_dice — stateless, zero side effect

    static func rollDiceTool() -> any Tool {
        struct Args: Decodable { let sides: Int?; let count: Int? }
        struct Out: Encodable { let rolls: [Int]; let total: Int }
        let spec = ToolSpec(
            name: "roll_dice",
            description: "Roll one or more N-sided dice. Useful for random decisions or games.",
            parameters: .object(
                properties: [
                    "sides": .integer(description: "Number of sides on each die.", minimum: 2, maximum: 1000),
                    "count": .integer(description: "How many dice to roll.", minimum: 1, maximum: 20)
                ],
                required: []
            ),
            requiresApproval: false,
            sideEffectFree: true
        )
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let sides = args.sides ?? 6
            let count = args.count ?? 1
            let rolls = (0..<count).map { _ in Int.random(in: 1...sides) }
            return Out(rolls: rolls, total: rolls.reduce(0, +))
        }
    }
}
