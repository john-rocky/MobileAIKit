import Foundation
import SwiftUI
import AIKit

@MainActor
@Observable
final class MealStore {
    private(set) var meals: [Meal] = []
    let memory: DatabaseMemoryStore
    let mediaDir: URL
    private let file: URL

    init() throws {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent("MealLog", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.mediaDir = dir.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        self.file = dir.appendingPathComponent("meals.json")
        self.memory = try DatabaseMemoryStore(
            fileURL: dir.appendingPathComponent("memory.sqlite3"),
            embedder: HashingEmbedder(dimension: 256)
        )
        load()
    }

    func add(_ meal: Meal) async throws {
        meals.insert(meal, at: 0)
        try save()
        try await memory.store(MemoryRecord(
            id: meal.id,
            kind: .episodic,
            namespace: "meals",
            text: meal.embedText,
            entities: meal.dishes.map(\.name) + [meal.kind.rawValue],
            importance: 0.7,
            metadata: [
                "mealId": meal.id.uuidString,
                "kind": meal.kind.rawValue,
                "calories": String(meal.estimatedCalories),
                "date": ISO8601DateFormatter().string(from: meal.date)
            ]
        ))
    }

    func delete(_ meal: Meal) async throws {
        meals.removeAll { $0.id == meal.id }
        try save()
        if let img = meal.imageFileName { try? FileManager.default.removeItem(at: mediaDir.appendingPathComponent(img)) }
        try await memory.forget(id: meal.id)
    }

    func search(_ query: String, limit: Int = 12) async throws -> [Meal] {
        let hits = try await memory.retrieve(query: query, namespace: "meals", limit: limit)
        let ids = hits.compactMap { UUID(uuidString: $0.metadata["mealId"] ?? "") }
        let dict = Dictionary(uniqueKeysWithValues: meals.map { ($0.id, $0) })
        return ids.compactMap { dict[$0] }
    }

    func mealsOn(_ day: Date) -> [Meal] {
        let cal = Calendar.current
        return meals.filter { cal.isDate($0.date, inSameDayAs: day) }
    }

    func dailyTotals(on day: Date) -> (calories: Int, protein: Double, carbs: Double, fat: Double) {
        let list = mealsOn(day)
        return (
            list.reduce(0) { $0 + $1.estimatedCalories },
            list.reduce(0) { $0 + $1.proteinGrams },
            list.reduce(0) { $0 + $1.carbsGrams },
            list.reduce(0) { $0 + $1.fatGrams }
        )
    }

    func imageURL(for meal: Meal) -> URL? {
        meal.imageFileName.map { mediaDir.appendingPathComponent($0) }
    }

    private func save() throws {
        try JSONEncoder().encode(meals).write(to: file, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let decoded = try? JSONDecoder().decode([Meal].self, from: data) else { return }
        self.meals = decoded
    }
}
