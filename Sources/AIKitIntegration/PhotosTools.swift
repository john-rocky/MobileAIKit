import Foundation
import AIKit
#if canImport(Photos)
import Photos
#endif

#if canImport(Photos)
public final class PhotosBridge: @unchecked Sendable {
    public init() {}

    public func requestAccess() async -> PHAuthorizationStatus {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                cont.resume(returning: status)
            }
        }
    }

    public func recentPhotosTool() -> any Tool {
        let spec = ToolSpec(
            name: "list_recent_photos",
            description: "List metadata of recent photos in the user library.",
            parameters: .object(
                properties: [
                    "limit": .integer(minimum: 1, maximum: 200)
                ],
                required: []
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let limit: Int? }
        struct Out: Encodable {
            let id: String; let date: String?; let width: Int; let height: Int
        }
        return TypedTool(spec: spec) { (args: Args) async throws -> [Out] in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.fetchLimit = args.limit ?? 20
            let assets = PHAsset.fetchAssets(with: .image, options: options)
            var results: [Out] = []
            assets.enumerateObjects { asset, _, _ in
                let df = ISO8601DateFormatter()
                results.append(Out(
                    id: asset.localIdentifier,
                    date: asset.creationDate.map { df.string(from: $0) },
                    width: asset.pixelWidth,
                    height: asset.pixelHeight
                ))
            }
            return results
        }
    }
}
#endif
