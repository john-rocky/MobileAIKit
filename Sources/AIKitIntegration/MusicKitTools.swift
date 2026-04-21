import Foundation
import AIKit
#if canImport(MusicKit)
import MusicKit

@available(iOS 16.0, macOS 14.0, *)
public final class MusicKitBridge: @unchecked Sendable {
    public init() {}

    public func requestAuthorization() async -> MusicAuthorization.Status {
        await MusicAuthorization.request()
    }

    public func searchSongsTool() -> any Tool {
        let spec = ToolSpec(
            name: "search_songs",
            description: "Search Apple Music for songs.",
            parameters: .object(
                properties: [
                    "query": .string(),
                    "limit": .integer(minimum: 1, maximum: 25)
                ],
                required: ["query"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let query: String; let limit: Int? }
        struct SongOut: Encodable {
            let title: String
            let artist: String
            let album: String?
            let id: String
            let duration: Double?
        }
        return TypedTool(spec: spec) { (args: Args) async throws -> [SongOut] in
            var request = MusicCatalogSearchRequest(term: args.query, types: [Song.self])
            request.limit = args.limit ?? 10
            let response = try await request.response()
            return response.songs.map { s in
                SongOut(
                    title: s.title,
                    artist: s.artistName,
                    album: s.albumTitle,
                    id: s.id.rawValue,
                    duration: s.duration
                )
            }
        }
    }

    public func playSongTool() -> any Tool {
        let spec = ToolSpec(
            name: "play_song",
            description: "Start playback of a song by Apple Music id.",
            parameters: .object(
                properties: ["songId": .string()],
                required: ["songId"]
            ),
            requiresApproval: true,
            sideEffectFree: false
        )
        struct Args: Decodable { let songId: String }
        struct Out: Encodable { let started: Bool }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(args.songId))
            let response = try await request.response()
            guard let song = response.items.first else { return Out(started: false) }
            let player = SystemMusicPlayer.shared
            player.queue = [song]
            try await player.play()
            return Out(started: true)
        }
    }
}
#endif
