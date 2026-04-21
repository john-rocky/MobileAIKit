import Foundation
import AIKit
#if canImport(HomeKit) && os(iOS)
import HomeKit

public final class HomeKitBridge: NSObject, @unchecked Sendable, HMHomeManagerDelegate {
    public let manager = HMHomeManager()
    private var readyContinuations: [CheckedContinuation<Void, Never>] = []

    public override init() {
        super.init()
        manager.delegate = self
    }

    public func ready() async {
        if manager.primaryHome != nil || !manager.homes.isEmpty { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            readyContinuations.append(cont)
        }
    }

    public func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        let snapshot = readyContinuations
        readyContinuations.removeAll()
        for c in snapshot { c.resume() }
    }

    public func listAccessoriesTool() -> any Tool {
        let spec = ToolSpec(
            name: "list_home_accessories",
            description: "List HomeKit accessories by room and category.",
            parameters: .object(properties: [:], required: []),
            sideEffectFree: true
        )
        struct Args: Decodable {}
        struct Accessory: Encodable {
            let name: String
            let room: String?
            let category: String
            let reachable: Bool
            let id: String
        }
        return TypedTool(spec: spec) { [manager] (_: Args) async throws -> [Accessory] in
            await self.ready()
            let home = manager.primaryHome ?? manager.homes.first
            guard let home else { return [] }
            return home.accessories.map { acc in
                Accessory(
                    name: acc.name,
                    room: acc.room?.name,
                    category: acc.category.categoryType,
                    reachable: acc.isReachable,
                    id: acc.uniqueIdentifier.uuidString
                )
            }
        }
    }

    public func setPowerStateTool() -> any Tool {
        let spec = ToolSpec(
            name: "set_accessory_power",
            description: "Turn a HomeKit accessory on or off by name.",
            parameters: .object(
                properties: [
                    "name": .string(description: "Accessory name"),
                    "on": .boolean()
                ],
                required: ["name", "on"]
            ),
            requiresApproval: true,
            sideEffectFree: false
        )
        struct Args: Decodable { let name: String; let on: Bool }
        struct Out: Encodable { let updated: Bool; let matchedAccessory: String? }
        return TypedTool(spec: spec) { [manager] (args: Args) async throws -> Out in
            await self.ready()
            let home = manager.primaryHome ?? manager.homes.first
            guard let home else { return Out(updated: false, matchedAccessory: nil) }
            guard let acc = home.accessories.first(where: { $0.name.localizedCaseInsensitiveContains(args.name) }) else {
                return Out(updated: false, matchedAccessory: nil)
            }
            var didSet = false
            for service in acc.services {
                for char in service.characteristics where char.characteristicType == HMCharacteristicTypePowerState {
                    try await char.writeValue(args.on)
                    didSet = true
                }
            }
            return Out(updated: didSet, matchedAccessory: acc.name)
        }
    }
}
#endif
