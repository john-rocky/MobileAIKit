import Foundation

/// Resolves the ``AgentHost`` to use for a given tool invocation.
///
/// Tools are registered ahead of time, but the host may not be attached yet
/// (e.g. `AIAgentView` is about to mount) and may change during the agent's
/// lifetime. A provider lets tools look up the current host at call time.
public typealias AgentHostProvider = @Sendable () async -> any AgentHost

/// Built-in tools that drive UI presentations through the agent's ``AgentHost``.
///
/// Register whichever you need onto an ``AIAgent``'s ``ToolRegistry``. Each tool
/// throws ``AgentHostError/noHost`` when the host is a ``NullAgentHost``, so a
/// headless agent reports a clean failure instead of silently hanging.
public enum AgentTools {
    // MARK: - Camera

    public static func takePhotoTool(hostProvider: @escaping AgentHostProvider) -> any Tool {
        let spec = ToolSpec(
            name: "take_photo",
            description: "Open the device camera so the user can capture a photo. Returns a reference to the captured image that other tools (ocr_image, analyze_image, send with image) can consume.",
            parameters: .object(
                properties: [
                    "camera": .string(enumValues: ["rear", "front"], description: "Which camera to open. Defaults to rear."),
                    "prompt": .string(description: "Optional short instruction shown to the user before they shoot.")
                ],
                required: []
            ),
            requiresApproval: false,
            sideEffectFree: false
        )
        struct Args: Decodable { let camera: String?; let prompt: String? }
        return TypedTool(spec: spec) { (args: Args) async throws -> AgentAttachmentStore.Entry in
            let host = await hostProvider()
            let camera: CameraOptions.Camera = args.camera == "front" ? .front : .rear
            let image = try await host.presentCamera(
                options: CameraOptions(preferredCamera: camera)
            )
            return await AgentAttachmentStore.shared.store(image)
        }
    }

    // MARK: - Photo picker

    public static func pickPhotosTool(hostProvider: @escaping AgentHostProvider) -> any Tool {
        let spec = ToolSpec(
            name: "pick_photos",
            description: "Open the photo library picker. Returns image references the assistant can pass back into other tools.",
            parameters: .object(
                properties: [
                    "max_count": .integer(minimum: 1, maximum: 20)
                ],
                required: []
            ),
            sideEffectFree: false
        )
        struct Args: Decodable { let max_count: Int? }
        return TypedTool(spec: spec) { (args: Args) async throws -> [AgentAttachmentStore.Entry] in
            let host = await hostProvider()
            let images = try await host.presentPhotoPicker(
                options: PhotoPickerOptions(maxCount: args.max_count ?? 1)
            )
            var entries: [AgentAttachmentStore.Entry] = []
            for image in images {
                entries.append(await AgentAttachmentStore.shared.store(image))
            }
            return entries
        }
    }

    // MARK: - Document scanner

    public static func scanDocumentTool(hostProvider: @escaping AgentHostProvider) -> any Tool {
        let spec = ToolSpec(
            name: "scan_document",
            description: "Open the document scanner (Vision) and return one image per scanned page.",
            parameters: .object(properties: [:], required: []),
            sideEffectFree: false
        )
        struct Args: Decodable {}
        return TypedTool(spec: spec) { (_: Args) async throws -> [AgentAttachmentStore.Entry] in
            let host = await hostProvider()
            let pages = try await host.presentDocumentScanner()
            var entries: [AgentAttachmentStore.Entry] = []
            for page in pages {
                entries.append(await AgentAttachmentStore.shared.store(page))
            }
            return entries
        }
    }

    // MARK: - Text / barcode scanner

    public static func scanTextTool(hostProvider: @escaping AgentHostProvider) -> any Tool {
        let spec = ToolSpec(
            name: "scan_text",
            description: "Open the live text / barcode scanner and return the recognized strings.",
            parameters: .object(
                properties: [
                    "types": .array(
                        items: .string(enumValues: ["text", "barcode", "qr"]),
                        description: "Recognition types to enable. Defaults to [text]."
                    )
                ],
                required: []
            ),
            sideEffectFree: false
        )
        struct Args: Decodable { let types: [String]? }
        struct Out: Encodable { let values: [String] }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let host = await hostProvider()
            let raw = args.types ?? ["text"]
            let types = Set(raw.compactMap { TextScannerOptions.ScanType(rawValue: $0) })
            let values = try await host.presentTextScanner(
                options: TextScannerOptions(types: types.isEmpty ? [.text] : types)
            )
            return Out(values: values)
        }
    }

    // MARK: - Location picker

    public static func pickLocationTool(hostProvider: @escaping AgentHostProvider) -> any Tool {
        let spec = ToolSpec(
            name: "pick_location",
            description: "Ask the user to pick a place on a map. Returns latitude/longitude for downstream tools (weather, directions, places).",
            parameters: .object(properties: [:], required: []),
            sideEffectFree: false
        )
        struct Args: Decodable {}
        return TypedTool(spec: spec) { (_: Args) async throws -> PickedLocation in
            let host = await hostProvider()
            return try await host.presentLocationPicker(options: .default)
        }
    }

    // MARK: - File picker

    public static func pickFilesTool(hostProvider: @escaping AgentHostProvider) -> any Tool {
        let spec = ToolSpec(
            name: "pick_files",
            description: "Present the files importer for the user to choose one or more documents.",
            parameters: .object(
                properties: [
                    "allows_multiple": .boolean(),
                    "content_types": .array(items: .string(), description: "Uniform Type Identifiers (e.g. public.pdf, public.image).")
                ],
                required: []
            ),
            sideEffectFree: false
        )
        struct Args: Decodable { let allows_multiple: Bool?; let content_types: [String]? }
        struct Out: Encodable { let filePaths: [String] }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let host = await hostProvider()
            let urls = try await host.presentFilePicker(
                options: FilePickerOptions(
                    allowsMultiple: args.allows_multiple ?? false,
                    contentTypeIdentifiers: args.content_types ?? []
                )
            )
            return Out(filePaths: urls.map(\.path))
        }
    }

    // MARK: - Share sheet

    public static func shareTool(hostProvider: @escaping AgentHostProvider) -> any Tool {
        let spec = ToolSpec(
            name: "share",
            description: "Open the system share sheet to send text, a URL, a file path, or a prior image reference somewhere else.",
            parameters: .object(
                properties: [
                    "text": .string(),
                    "url": .string(format: "uri"),
                    "file_path": .string(),
                    "image_id": .string(description: "An image id returned by take_photo / pick_photos.")
                ],
                required: []
            ),
            requiresApproval: true,
            sideEffectFree: false
        )
        struct Args: Decodable {
            let text: String?; let url: String?; let file_path: String?; let image_id: String?
        }
        struct Out: Encodable { let shared: Bool }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            var items: [ShareItem] = []
            if let t = args.text { items.append(.text(t)) }
            if let u = args.url, let url = URL(string: u) { items.append(.url(url)) }
            if let p = args.file_path { items.append(.file(URL(fileURLWithPath: p))) }
            if let id = args.image_id,
               let image = await AgentAttachmentStore.shared.image(forId: id) {
                items.append(.image(image))
            }
            guard !items.isEmpty else {
                throw AIError.toolArgumentsInvalid(tool: "share", reason: "Provide at least one of text, url, file_path, image_id.")
            }
            let host = await hostProvider()
            try await host.presentShareSheet(items: items)
            return Out(shared: true)
        }
    }

    // MARK: - Open URL

    public static func openURLTool(hostProvider: @escaping AgentHostProvider) -> any Tool {
        let spec = ToolSpec(
            name: "open_url",
            description: "Open a URL in the system browser or the appropriate app (mailto:, tel:, maps://, etc.).",
            parameters: .object(
                properties: ["url": .string(format: "uri")],
                required: ["url"]
            ),
            requiresApproval: true,
            sideEffectFree: false
        )
        struct Args: Decodable { let url: String }
        struct Out: Encodable { let opened: Bool }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            guard let url = URL(string: args.url) else {
                throw AIError.toolArgumentsInvalid(tool: "open_url", reason: "Invalid URL \(args.url)")
            }
            let host = await hostProvider()
            try await host.openURL(url)
            return Out(opened: true)
        }
    }

    // MARK: - Attachment access helpers

    public static func describeImageTool(
        backendProvider: @escaping @Sendable () async -> any AIBackend
    ) -> any Tool {
        let spec = ToolSpec(
            name: "describe_image",
            description: "Describe an image captured earlier (by image_id) or at a file path, using the vision-capable backend.",
            parameters: .object(
                properties: [
                    "image_id": .string(description: "Id returned by take_photo / pick_photos."),
                    "file_path": .string(description: "Absolute path to an image file."),
                    "prompt": .string(description: "Optional prompt / question about the image.")
                ],
                required: []
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let image_id: String?; let file_path: String?; let prompt: String? }
        struct Out: Encodable { let description: String }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            var attachment: ImageAttachment?
            if let id = args.image_id {
                attachment = await AgentAttachmentStore.shared.image(forId: id)
            } else if let path = args.file_path {
                attachment = ImageAttachment(source: .fileURL(URL(fileURLWithPath: path)))
            }
            guard let image = attachment else {
                throw AIError.toolArgumentsInvalid(tool: "describe_image", reason: "Provide image_id or file_path.")
            }
            let backend = await backendProvider()
            let prompt = args.prompt ?? "Describe this image in detail."
            let message = Message.user(prompt, attachments: [.image(image)])
            let result = try await backend.generate(messages: [message], tools: [], config: .default)
            return Out(description: result.message.content)
        }
    }

    /// Convenience: every built-in host-presenting tool in one array.
    public static func all(hostProvider: @escaping AgentHostProvider) -> [any Tool] {
        [
            takePhotoTool(hostProvider: hostProvider),
            pickPhotosTool(hostProvider: hostProvider),
            scanDocumentTool(hostProvider: hostProvider),
            scanTextTool(hostProvider: hostProvider),
            pickLocationTool(hostProvider: hostProvider),
            pickFilesTool(hostProvider: hostProvider),
            shareTool(hostProvider: hostProvider),
            openURLTool(hostProvider: hostProvider)
        ]
    }
}

/// Process-wide cache of images captured / picked via agent tools.
///
/// Tool results must be JSON-representable, so captured images are stored here
/// and a short `imageId` is returned to the model. Downstream tools
/// (`describe_image`, `share`, custom dev tools) look the image back up by id.
public actor AgentAttachmentStore {
    public static let shared = AgentAttachmentStore()

    public struct Entry: Sendable, Hashable, Codable {
        public let imageId: String
        public let width: Int?
        public let height: Int?
        public let mimeType: String
        public let filePath: String?
    }

    private var images: [String: ImageAttachment] = [:]
    private var insertionOrder: [String] = []
    private let capacity: Int

    public init(capacity: Int = 32) {
        self.capacity = capacity
    }

    @discardableResult
    public func store(_ image: ImageAttachment) -> Entry {
        let id = "img_" + UUID().uuidString.prefix(8).lowercased()
        images[id] = image
        insertionOrder.append(id)
        evictIfNeeded()
        var filePath: String?
        if case let .fileURL(url) = image.source { filePath = url.path }
        return Entry(
            imageId: id,
            width: image.width,
            height: image.height,
            mimeType: image.mimeType,
            filePath: filePath
        )
    }

    public func image(forId id: String) -> ImageAttachment? {
        images[id]
    }

    public func clear() {
        images.removeAll()
        insertionOrder.removeAll()
    }

    private func evictIfNeeded() {
        while insertionOrder.count > capacity {
            let oldest = insertionOrder.removeFirst()
            images.removeValue(forKey: oldest)
        }
    }
}
