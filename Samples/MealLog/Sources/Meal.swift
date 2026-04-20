import Foundation
import AIKit

struct Meal: Codable, Identifiable, Hashable {
    let id: UUID
    var date: Date
    var kind: Kind
    var title: String
    var description: String
    var dishes: [Dish]
    var estimatedCalories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var dietaryFlags: [String]
    var imageFileName: String?

    enum Kind: String, Codable, CaseIterable, Hashable {
        case breakfast, lunch, dinner, snack
        var emoji: String {
            switch self {
            case .breakfast: return "🍳"
            case .lunch: return "🥗"
            case .dinner: return "🍽️"
            case .snack: return "🍪"
            }
        }
    }

    struct Dish: Codable, Hashable, Identifiable {
        var id: String { name }
        let name: String
        let portion: String?
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        kind: Kind,
        title: String,
        description: String,
        dishes: [Dish],
        estimatedCalories: Int,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        dietaryFlags: [String] = [],
        imageFileName: String? = nil
    ) {
        self.id = id; self.date = date; self.kind = kind
        self.title = title; self.description = description
        self.dishes = dishes
        self.estimatedCalories = estimatedCalories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.dietaryFlags = dietaryFlags
        self.imageFileName = imageFileName
    }

    var embedText: String {
        var s = "[\(kind.rawValue)] \(title)\n\(description)"
        if !dishes.isEmpty {
            s += "\nDishes: " + dishes.map { [$0.name, $0.portion ?? ""].joined(separator: " ") }.joined(separator: ", ")
        }
        s += "\nCalories: \(estimatedCalories) kcal, P: \(Int(proteinGrams))g, C: \(Int(carbsGrams))g, F: \(Int(fatGrams))g"
        if !dietaryFlags.isEmpty { s += "\nFlags: " + dietaryFlags.joined(separator: ", ") }
        return s
    }

    var spokenSummary: String {
        let dishList = dishes.map(\.name).joined(separator: ", ")
        return "\(kind.rawValue.capitalized): \(title). \(dishList). Around \(estimatedCalories) calories."
    }
}

struct MealExtraction: Codable {
    let kind: String
    let title: String
    let description: String
    let dishes: [Meal.Dish]
    let estimatedCalories: Int
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let dietaryFlags: [String]

    static let schema: JSONSchema = .object(
        properties: [
            "kind": .string(enumValues: Meal.Kind.allCases.map(\.rawValue)),
            "title": .string(description: "3-6 word title, e.g. 'Tuna onigiri lunch'"),
            "description": .string(description: "1-2 sentence description of the meal."),
            "dishes": .array(items: .object(
                properties: ["name": .string(), "portion": .string()],
                required: ["name"]
            )),
            "estimatedCalories": .integer(minimum: 0, maximum: 5000),
            "proteinGrams": .number(minimum: 0, maximum: 300),
            "carbsGrams": .number(minimum: 0, maximum: 500),
            "fatGrams": .number(minimum: 0, maximum: 300),
            "dietaryFlags": .array(items: .string(), description: "e.g. vegetarian, high-protein, contains-gluten")
        ],
        required: ["kind", "title", "description", "dishes", "estimatedCalories", "proteinGrams", "carbsGrams", "fatGrams"]
    )
}
