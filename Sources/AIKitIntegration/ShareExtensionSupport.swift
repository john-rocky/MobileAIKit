import Foundation
import AIKit
#if canImport(UIKit)
import UIKit
#endif

public struct SharedItem: Sendable {
    public let text: String?
    public let urls: [URL]
    public let imageData: [Data]

    public init(text: String? = nil, urls: [URL] = [], imageData: [Data] = []) {
        self.text = text
        self.urls = urls
        self.imageData = imageData
    }
}

#if canImport(UIKit)
public enum ShareExtensionHelper {
    public static func parseInputItems(_ items: [NSExtensionItem]) async -> SharedItem {
        var text: String?
        var urls: [URL] = []
        var images: [Data] = []

        for item in items {
            for provider in (item.attachments ?? []) {
                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    if let obj = try? await provider.loadItem(forTypeIdentifier: "public.plain-text") as? String {
                        text = obj
                    }
                } else if provider.hasItemConformingToTypeIdentifier("public.url") {
                    if let obj = try? await provider.loadItem(forTypeIdentifier: "public.url") as? URL {
                        urls.append(obj)
                    }
                } else if provider.hasItemConformingToTypeIdentifier("public.image") {
                    if let obj = try? await provider.loadItem(forTypeIdentifier: "public.image") {
                        if let data = obj as? Data { images.append(data) }
                        else if let url = obj as? URL, let data = try? Data(contentsOf: url) { images.append(data) }
                        else if let image = obj as? UIImage, let data = image.pngData() { images.append(data) }
                    }
                }
            }
        }
        return SharedItem(text: text, urls: urls, imageData: images)
    }

    public static func toAttachments(_ shared: SharedItem) -> [Attachment] {
        var atts: [Attachment] = []
        if let text = shared.text { atts.append(.text(TextAttachment(text: text))) }
        for url in shared.urls { atts.append(.file(FileAttachment(fileURL: url))) }
        for data in shared.imageData { atts.append(.image(ImageAttachment(source: .data(data)))) }
        return atts
    }
}
#endif
