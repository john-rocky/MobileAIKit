import Foundation
import AIKit

/// Shared nutrition shape used by food-tracking apps: calories, macros, water.
///
/// Designed for the common ``AIKit/extract(_:from:schema:instruction:backend:)`` pipeline —
/// pass ``jsonSchema`` to the model, decode the reply as ``NutritionEntry``, then feed
/// the result to `HealthKitBridge.saveMeal(_:date:)`.
///
/// Every macro is optional so the model (or user) can report only what it can see —
/// the HealthKit write path skips `nil` / zero fields rather than zero-writing them.
///
/// ## Extending vs wrapping
///
/// The library deliberately keeps this type HealthKit-shaped — calories, macros, water —
/// and nothing else. App-specific fields that **HealthKit doesn't model** (meal kind like
/// breakfast/lunch/dinner, dietary flags like vegan/halal, dish photos, UI badges) should
/// live on a **wrapping** type, not on a subclass / extension of ``NutritionEntry``:
///
/// ```swift
/// struct MealEntry: Codable {
///     var nutrition: NutritionEntry        // feeds HealthKitBridge.saveMeal directly
///     var kind: MealKind                   // breakfast / lunch / ...
///     var dietaryFlags: [DietaryFlag]
///     var imageFileName: String?
/// }
/// ```
///
/// Wrapping keeps the HealthKit write path (which only needs the nutrition slice)
/// trivial, and lets you evolve app-specific fields without fighting the
/// ``jsonSchema`` contract the model was prompted against.
public struct NutritionEntry: Codable, Hashable, Sendable {
    public var name: String?
    public var calories: Double?
    public var proteinGrams: Double?
    public var carbohydrateGrams: Double?
    public var fatGrams: Double?
    public var fiberGrams: Double?
    public var sugarGrams: Double?
    public var waterMilliliters: Double?
    public var servingDescription: String?
    public var dishes: [Dish]?

    public struct Dish: Codable, Hashable, Sendable {
        public var name: String
        public var calories: Double?
        public var proteinGrams: Double?
        public var carbohydrateGrams: Double?
        public var fatGrams: Double?

        public init(
            name: String,
            calories: Double? = nil,
            proteinGrams: Double? = nil,
            carbohydrateGrams: Double? = nil,
            fatGrams: Double? = nil
        ) {
            self.name = name
            self.calories = calories
            self.proteinGrams = proteinGrams
            self.carbohydrateGrams = carbohydrateGrams
            self.fatGrams = fatGrams
        }
    }

    public init(
        name: String? = nil,
        calories: Double? = nil,
        proteinGrams: Double? = nil,
        carbohydrateGrams: Double? = nil,
        fatGrams: Double? = nil,
        fiberGrams: Double? = nil,
        sugarGrams: Double? = nil,
        waterMilliliters: Double? = nil,
        servingDescription: String? = nil,
        dishes: [Dish]? = nil
    ) {
        self.name = name
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.waterMilliliters = waterMilliliters
        self.servingDescription = servingDescription
        self.dishes = dishes
    }

    /// JSON Schema ready to pass to ``AIKit/extract(_:from:schema:instruction:backend:)``.
    public static var jsonSchema: JSONSchema {
        let dish: JSONSchema = .object(
            properties: [
                "name": .string(),
                "calories": .number(minimum: 0),
                "proteinGrams": .number(minimum: 0),
                "carbohydrateGrams": .number(minimum: 0),
                "fatGrams": .number(minimum: 0)
            ],
            required: ["name"]
        )
        return .object(
            properties: [
                "name": .string(),
                "calories": .number(minimum: 0),
                "proteinGrams": .number(minimum: 0),
                "carbohydrateGrams": .number(minimum: 0),
                "fatGrams": .number(minimum: 0),
                "fiberGrams": .number(minimum: 0),
                "sugarGrams": .number(minimum: 0),
                "waterMilliliters": .number(minimum: 0),
                "servingDescription": .string(),
                "dishes": .array(items: dish)
            ],
            required: []
        )
    }

    /// Default instruction for vision-based extraction from a meal photo.
    public static let defaultInstruction = """
    Identify the meal in the photo. Estimate calories and macronutrients for the full plate. \
    Return grams for protein, carbohydrates, fat, and (when visible) fiber and sugar. \
    Return milliliters for any drink. Leave fields null when you cannot see enough to estimate.
    """
}
