import Foundation
import AIKit
#if canImport(CoreData)
import CoreData

public final class CoreDataIndexer: @unchecked Sendable {
    public let context: NSManagedObjectContext
    public let index: VectorIndex

    public init(context: NSManagedObjectContext, index: VectorIndex) {
        self.context = context
        self.index = index
    }

    public func index(
        entityName: String,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor] = [],
        toText: @escaping (NSManagedObject) -> String,
        source: String,
        chunker: Chunker = Chunker()
    ) async throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        let objects: [NSManagedObject] = try await context.perform { try self.context.fetch(request) }
        var chunks: [Chunk] = []
        for obj in objects {
            let text = toText(obj)
            let perObjSource = "\(source)/\(obj.objectID.uriRepresentation().absoluteString)"
            chunks.append(contentsOf: chunker.chunk(text, source: perObjSource))
        }
        try await index.add(chunks)
    }
}
#endif
