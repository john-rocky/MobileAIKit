import Foundation
import AIKit
#if canImport(RealityKit)
import RealityKit

public enum RealityKitBridge {
    /// Load a USDZ/Reality file from disk.
    @MainActor
    public static func loadEntity(url: URL) async throws -> Entity {
        try await Entity(contentsOf: url)
    }

    /// Quick anchor + entity convenience for placing a loaded model at world origin.
    @MainActor
    public static func placeAnchor(for entity: Entity) -> AnchorEntity {
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(entity)
        return anchor
    }

    #if canImport(ARKit) && os(iOS)
    /// Makes an entity pulse in place — useful to flag an LLM-highlighted object in AR.
    @MainActor
    public static func pulse(_ entity: Entity, period: Double = 1.0) {
        var transform = entity.transform
        let original = transform.scale
        transform.scale = original * 1.15
        entity.move(to: transform, relativeTo: entity.parent, duration: period / 2, timingFunction: .easeInOut)
    }
    #endif
}
#endif
