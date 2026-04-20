import Foundation

public struct HierarchicalChunker: Sendable {
    public var topLevelChars: Int
    public var midLevelChars: Int
    public var leafChars: Int
    public var overlap: Int

    public init(topLevelChars: Int = 4000, midLevelChars: Int = 1200, leafChars: Int = 400, overlap: Int = 60) {
        self.topLevelChars = topLevelChars
        self.midLevelChars = midLevelChars
        self.leafChars = leafChars
        self.overlap = overlap
    }

    public func chunk(_ text: String, source: String, metadata: [String: String] = [:]) -> [Chunk] {
        let topChunks = Chunker(maxCharacters: topLevelChars, overlap: 0, respectParagraphs: true).chunk(text, source: source, metadata: metadata)
        var all: [Chunk] = []
        for (i, top) in topChunks.enumerated() {
            var topMeta = top.metadata
            topMeta["level"] = "top"
            topMeta["topIndex"] = "\(i)"
            all.append(Chunk(id: top.id, text: top.text, source: top.source, startOffset: top.startOffset, endOffset: top.endOffset, metadata: topMeta))

            let midChunks = Chunker(maxCharacters: midLevelChars, overlap: overlap, respectParagraphs: true).chunk(top.text, source: top.source)
            for (j, mid) in midChunks.enumerated() {
                var midMeta = metadata
                midMeta["level"] = "mid"
                midMeta["topIndex"] = "\(i)"
                midMeta["midIndex"] = "\(j)"
                all.append(Chunk(text: mid.text, source: top.source, startOffset: top.startOffset + mid.startOffset, endOffset: top.startOffset + mid.endOffset, metadata: midMeta))

                let leafChunks = Chunker(maxCharacters: leafChars, overlap: overlap, respectParagraphs: false).chunk(mid.text, source: top.source)
                for (k, leaf) in leafChunks.enumerated() {
                    var leafMeta = metadata
                    leafMeta["level"] = "leaf"
                    leafMeta["topIndex"] = "\(i)"
                    leafMeta["midIndex"] = "\(j)"
                    leafMeta["leafIndex"] = "\(k)"
                    all.append(Chunk(text: leaf.text, source: top.source, startOffset: top.startOffset + mid.startOffset + leaf.startOffset, endOffset: top.startOffset + mid.startOffset + leaf.endOffset, metadata: leafMeta))
                }
            }
        }
        return all
    }
}
