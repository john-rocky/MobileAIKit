import Foundation

public struct Chunk: Sendable, Hashable, Codable {
    public let id: UUID
    public let text: String
    public let source: String
    public let startOffset: Int
    public let endOffset: Int
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        text: String,
        source: String,
        startOffset: Int,
        endOffset: Int,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.text = text
        self.source = source
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.metadata = metadata
    }
}

public struct Chunker: Sendable {
    public var maxCharacters: Int
    public var overlap: Int
    public var respectParagraphs: Bool

    public init(maxCharacters: Int = 800, overlap: Int = 80, respectParagraphs: Bool = true) {
        self.maxCharacters = maxCharacters
        self.overlap = overlap
        self.respectParagraphs = respectParagraphs
    }

    public func chunk(_ text: String, source: String, metadata: [String: String] = [:]) -> [Chunk] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        if respectParagraphs {
            return chunkByParagraphs(normalized, source: source, metadata: metadata)
        }
        return chunkFixedWindow(normalized, source: source, metadata: metadata)
    }

    private func chunkByParagraphs(_ text: String, source: String, metadata: [String: String]) -> [Chunk] {
        var chunks: [Chunk] = []
        var offset = 0
        var buffer = ""
        var bufferStart = 0

        let paragraphs = text.components(separatedBy: "\n\n")

        func flush() {
            guard !buffer.isEmpty else { return }
            chunks.append(Chunk(
                text: buffer,
                source: source,
                startOffset: bufferStart,
                endOffset: bufferStart + buffer.count,
                metadata: metadata
            ))
            buffer = ""
        }

        for (i, p) in paragraphs.enumerated() {
            let pOffset = offset
            if !p.isEmpty {
                if buffer.isEmpty {
                    buffer = p
                    bufferStart = pOffset
                } else if buffer.count + 2 + p.count <= maxCharacters {
                    buffer += "\n\n" + p
                } else {
                    flush()
                    buffer = p
                    bufferStart = pOffset
                }
                if buffer.count >= maxCharacters {
                    flush()
                }
            }
            offset += p.count
            if i < paragraphs.count - 1 { offset += 2 }
        }
        flush()
        return chunks
    }

    private func chunkFixedWindow(_ text: String, source: String, metadata: [String: String]) -> [Chunk] {
        var chunks: [Chunk] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: maxCharacters, limitedBy: text.endIndex) ?? text.endIndex
            let slice = String(text[start..<end])
            let startOffset = text.distance(from: text.startIndex, to: start)
            let endOffset = text.distance(from: text.startIndex, to: end)
            chunks.append(Chunk(
                text: slice,
                source: source,
                startOffset: startOffset,
                endOffset: endOffset,
                metadata: metadata
            ))
            if end == text.endIndex { break }
            let back = text.index(end, offsetBy: -overlap, limitedBy: start) ?? start
            start = back
        }
        return chunks
    }
}
