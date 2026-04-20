import Foundation
import AIKit
#if canImport(StoreKit)
import StoreKit

public enum StoreKitBridge {
    public static func listPurchasesTool() -> any Tool {
        let spec = ToolSpec(
            name: "list_active_entitlements",
            description: "Return the user's currently active StoreKit entitlements.",
            parameters: .object(properties: [:], required: []),
            sideEffectFree: true
        )
        struct Args: Decodable {}
        struct Out: Encodable { let productId: String; let purchaseDate: String? }
        return TypedTool(spec: spec) { (_: Args) async throws -> [Out] in
            var results: [Out] = []
            for await entitlement in Transaction.currentEntitlements {
                if case .verified(let transaction) = entitlement {
                    let iso = ISO8601DateFormatter()
                    results.append(Out(productId: transaction.productID, purchaseDate: iso.string(from: transaction.purchaseDate)))
                }
            }
            return results
        }
    }
}
#endif
