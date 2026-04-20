import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#if canImport(CoreImage)
import CoreImage
#endif

public enum Attachment: Sendable, Hashable, Codable {
    case image(ImageAttachment)
    case audio(AudioAttachment)
    case video(VideoAttachment)
    case pdf(PDFAttachment)
    case text(TextAttachment)
    case file(FileAttachment)

    public var mimeType: String {
        switch self {
        case .image(let a): return a.mimeType
        case .audio(let a): return a.mimeType
        case .video(let a): return a.mimeType
        case .pdf: return "application/pdf"
        case .text: return "text/plain"
        case .file(let a): return a.mimeType
        }
    }
}

public struct ImageAttachment: Sendable, Hashable, Codable {
    public enum Source: Sendable, Hashable, Codable {
        case data(Data)
        case url(URL)
        case fileURL(URL)
    }

    public let source: Source
    public let width: Int?
    public let height: Int?
    public let mimeType: String
    public let caption: String?

    public init(
        source: Source,
        width: Int? = nil,
        height: Int? = nil,
        mimeType: String = "image/png",
        caption: String? = nil
    ) {
        self.source = source
        self.width = width
        self.height = height
        self.mimeType = mimeType
        self.caption = caption
    }

    public func loadData() async throws -> Data {
        switch source {
        case .data(let d): return d
        case .fileURL(let u): return try Data(contentsOf: u)
        case .url(let u):
            let (d, _) = try await URLSession.shared.data(from: u)
            return d
        }
    }

    #if canImport(UIKit)
    public func loadUIImage() async throws -> UIImage {
        let data = try await loadData()
        guard let image = UIImage(data: data) else {
            throw AIError.invalidAttachment("Unable to decode image")
        }
        return image
    }
    #endif

    public func downsampled(maxPixels: Int) async throws -> ImageAttachment {
        let data = try await loadData()
        #if canImport(CoreImage)
        guard let ci = CIImage(data: data) else {
            throw AIError.invalidAttachment("Unable to decode image")
        }
        let current = Int(ci.extent.width * ci.extent.height)
        guard current > maxPixels else { return self }
        let scale = (Double(maxPixels) / Double(current)).squareRoot()
        let transformed = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let ctx = CIContext()
        let newW = Int(transformed.extent.width)
        let newH = Int(transformed.extent.height)
        guard let cg = ctx.createCGImage(transformed, from: transformed.extent) else {
            throw AIError.invalidAttachment("Unable to render image")
        }
        #if canImport(UIKit)
        let ui = UIImage(cgImage: cg)
        guard let newData = ui.pngData() else {
            throw AIError.invalidAttachment("Unable to encode image")
        }
        return ImageAttachment(source: .data(newData), width: newW, height: newH, mimeType: "image/png", caption: caption)
        #elseif canImport(AppKit)
        let ns = NSImage(cgImage: cg, size: NSSize(width: newW, height: newH))
        guard let tiff = ns.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let newData = rep.representation(using: .png, properties: [:]) else {
            throw AIError.invalidAttachment("Unable to encode image")
        }
        return ImageAttachment(source: .data(newData), width: newW, height: newH, mimeType: "image/png", caption: caption)
        #else
        return self
        #endif
        #else
        return self
        #endif
    }
}

public struct AudioAttachment: Sendable, Hashable, Codable {
    public enum Source: Sendable, Hashable, Codable {
        case data(Data)
        case fileURL(URL)
    }
    public let source: Source
    public let mimeType: String
    public let durationSeconds: Double?
    public let sampleRate: Int?

    public init(
        source: Source,
        mimeType: String = "audio/wav",
        durationSeconds: Double? = nil,
        sampleRate: Int? = nil
    ) {
        self.source = source
        self.mimeType = mimeType
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
    }

    public func loadData() throws -> Data {
        switch source {
        case .data(let d): return d
        case .fileURL(let u): return try Data(contentsOf: u)
        }
    }
}

public struct VideoAttachment: Sendable, Hashable, Codable {
    public let fileURL: URL
    public let mimeType: String
    public let durationSeconds: Double?

    public init(fileURL: URL, mimeType: String = "video/mp4", durationSeconds: Double? = nil) {
        self.fileURL = fileURL
        self.mimeType = mimeType
        self.durationSeconds = durationSeconds
    }
}

public struct PDFAttachment: Sendable, Hashable, Codable {
    public let fileURL: URL
    public let pageRange: ClosedRange<Int>?

    public init(fileURL: URL, pageRange: ClosedRange<Int>? = nil) {
        self.fileURL = fileURL
        self.pageRange = pageRange
    }
}

public struct TextAttachment: Sendable, Hashable, Codable {
    public let text: String
    public let title: String?

    public init(text: String, title: String? = nil) {
        self.text = text
        self.title = title
    }
}

public struct FileAttachment: Sendable, Hashable, Codable {
    public let fileURL: URL
    public let mimeType: String

    public init(fileURL: URL, mimeType: String = "application/octet-stream") {
        self.fileURL = fileURL
        self.mimeType = mimeType
    }
}
