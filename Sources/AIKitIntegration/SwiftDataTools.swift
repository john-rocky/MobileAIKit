import Foundation
import AIKit
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@available(iOS 17.0, macOS 14.0, *)
public final class SwiftDataIndexer: @unchecked Sendable {
    public let container: ModelContainer
    public let index: VectorIndex

    public init(container: ModelContainer, index: VectorIndex) {
        self.container = container
        self.index = index
    }

    public func indexObjects<Model: PersistentModel>(
        of type: Model.Type,
        toText: @escaping (Model) -> String,
        source: String,
        chunker: Chunker = Chunker()
    ) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Model>()
        let objects = try context.fetch(descriptor)
        var chunks: [Chunk] = []
        for obj in objects {
            let text = toText(obj)
            let objSource = "\(source)/\(obj.persistentModelID.entityName)"
            let objChunks = chunker.chunk(text, source: objSource)
            chunks.append(contentsOf: objChunks)
        }
        try await index.add(chunks)
    }
}
#endif
