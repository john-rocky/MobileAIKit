import SwiftUI
import AIKit
import UniformTypeIdentifiers
#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import UIKit
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif

/// Drop-in SwiftUI surface for a general-purpose AI agent.
///
/// Embed `AIAgentView(backend: backend)` and the user can chat with a model
/// that drives your app: take a photo, pick a location on the map, scan a
/// barcode, read calendar events, search the web, and call whatever custom
/// tools you register.
///
/// `AIAgentView` installs itself as the agent's ``AgentHost`` — sheets, pickers,
/// and confirmation dialogs are presented automatically over the view.
///
/// ```swift
/// struct ContentView: View {
///     let backend = CoreMLLLMBackend(model: .gemma4e2b)
///     var body: some View {
///         AIAgentView(backend: backend)
///     }
/// }
/// ```
///
/// Register custom tools via the `tools:` argument or by calling
/// `agent.addTool(_:)` on the wrapped ``AIAgent``.
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
@MainActor
public struct AIAgentView: View {
    @State private var agent: AIAgent
    @State private var host: SwiftUIAgentHost
    private let additionalTools: [any Tool]

    public init(
        backend: any AIBackend,
        systemPrompt: String? = nil,
        tools: [any Tool] = [],
        options: AIAgentOptions = .default
    ) {
        let host = SwiftUIAgentHost()
        let agent = AIAgent(
            backend: backend,
            host: host,
            systemPrompt: systemPrompt,
            tools: [],
            options: options
        )
        _agent = State(initialValue: agent)
        _host = State(initialValue: host)
        self.additionalTools = tools
    }

    /// Advanced: present a caller-owned ``AIAgent`` (e.g. one you built in a view
    /// model). The view still installs a ``SwiftUIAgentHost`` and overwrites
    /// `agent.host` with it.
    public init(agent: AIAgent, additionalTools: [any Tool] = []) {
        let host = SwiftUIAgentHost()
        agent.host = host
        _agent = State(initialValue: agent)
        _host = State(initialValue: host)
        self.additionalTools = additionalTools
    }

    /// The wrapped agent. Expose via `@Bindable` if you need to observe it externally.
    public var underlyingAgent: AIAgent { agent }

    public var body: some View {
        VStack(spacing: 0) {
            AIChatView(session: agent.session)
            if let status = host.status {
                Text(status)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: host.status)
        .task {
            await agent.registerHostTools()
            if !additionalTools.isEmpty {
                await agent.addTools(additionalTools)
            }
        }
        .modifier(AgentHostPresentations(host: host))
    }
}

/// Attaches every sheet / fullScreenCover / alert that the ``SwiftUIAgentHost``
/// can drive. Split out of ``AIAgentView`` so it can be reused by developers
/// embedding their own chat UI around an ``AIAgent``.
@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AgentHostPresentations: ViewModifier {
    @Bindable public var host: SwiftUIAgentHost

    public init(host: SwiftUIAgentHost) {
        self.host = host
    }

    public func body(content: Content) -> some View {
        content
            .modifier(CameraPresenter(host: host))
            .modifier(PhotoPickerPresenter(host: host))
            .modifier(DocumentScannerPresenter(host: host))
            .modifier(TextScannerPresenter(host: host))
            .modifier(LocationPickerPresenter(host: host))
            .modifier(FilePickerPresenter(host: host))
            .modifier(SharePresenter(host: host))
            .modifier(ConfirmPresenter(host: host))
    }
}

// MARK: - Individual presenters

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
private struct CameraPresenter: ViewModifier {
    @Bindable var host: SwiftUIAgentHost

    func body(content: Content) -> some View {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        content.fullScreenCover(isPresented: Binding(
            get: { if case .camera = host.pending { return true } else { return false } },
            set: { if !$0 { host.resolveCamera(with: nil) } }
        )) {
            if case let .camera(options, _) = host.pending {
                AgentCameraPicker(options: options) { image in
                    host.resolveCamera(with: image)
                }
                .ignoresSafeArea()
            }
        }
        #else
        content
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
private struct PhotoPickerPresenter: ViewModifier {
    @Bindable var host: SwiftUIAgentHost
    #if canImport(PhotosUI)
    @State private var selection: [PhotosPickerItem] = []
    #endif

    func body(content: Content) -> some View {
        #if canImport(PhotosUI)
        content
            .photosPicker(
                isPresented: Binding(
                    get: { if case .photoPicker = host.pending { return true } else { return false } },
                    set: { newValue in
                        if !newValue && selection.isEmpty {
                            host.resolvePhotos(with: [])
                        }
                    }
                ),
                selection: $selection,
                maxSelectionCount: pickerMaxCount(),
                matching: .images
            )
            .onChange(of: selection) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    var out: [ImageAttachment] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            out.append(ImageAttachment(source: .data(data), mimeType: "image/jpeg"))
                        }
                    }
                    await MainActor.run {
                        host.resolvePhotos(with: out)
                        selection.removeAll()
                    }
                }
            }
        #else
        content
        #endif
    }

    private func pickerMaxCount() -> Int {
        if case let .photoPicker(options, _) = host.pending { return options.maxCount }
        return 1
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
private struct DocumentScannerPresenter: ViewModifier {
    @Bindable var host: SwiftUIAgentHost

    func body(content: Content) -> some View {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        content.fullScreenCover(isPresented: Binding(
            get: { if case .documentScanner = host.pending { return true } else { return false } },
            set: { if !$0 { host.resolveDocumentScanner(with: nil) } }
        )) {
            AgentDocumentScanner { images in
                host.resolveDocumentScanner(with: images)
            }
            .ignoresSafeArea()
        }
        #else
        content
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
private struct TextScannerPresenter: ViewModifier {
    @Bindable var host: SwiftUIAgentHost

    func body(content: Content) -> some View {
        #if canImport(VisionKit) && os(iOS)
        content.fullScreenCover(isPresented: Binding(
            get: { if case .textScanner = host.pending { return true } else { return false } },
            set: { if !$0 { host.resolveTextScanner(with: nil) } }
        )) {
            if case let .textScanner(options, _) = host.pending {
                NavigationStack {
                    AgentLiveScanner(options: options) { values in
                        host.resolveTextScanner(with: values)
                    }
                    .ignoresSafeArea()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { host.resolveTextScanner(with: nil) }
                        }
                    }
                }
            }
        }
        #else
        content
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
private struct LocationPickerPresenter: ViewModifier {
    @Bindable var host: SwiftUIAgentHost

    func body(content: Content) -> some View {
        #if canImport(MapKit) && canImport(UIKit) && !os(watchOS) && !os(tvOS)
        content.sheet(isPresented: Binding(
            get: { if case .locationPicker = host.pending { return true } else { return false } },
            set: { if !$0 { host.resolveLocation(with: nil) } }
        )) {
            if case let .locationPicker(options, _) = host.pending {
                AgentLocationPicker(options: options) { loc in
                    host.resolveLocation(with: loc)
                }
            }
        }
        #else
        content
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
private struct FilePickerPresenter: ViewModifier {
    @Bindable var host: SwiftUIAgentHost

    func body(content: Content) -> some View {
        content.fileImporter(
            isPresented: Binding(
                get: { if case .filePicker = host.pending { return true } else { return false } },
                set: { if !$0 { host.resolveFiles(with: nil) } }
            ),
            allowedContentTypes: allowedTypes(),
            allowsMultipleSelection: {
                if case let .filePicker(options, _) = host.pending { return options.allowsMultiple }
                return false
            }()
        ) { result in
            switch result {
            case .success(let urls): host.resolveFiles(with: urls)
            case .failure: host.resolveFiles(with: nil)
            }
        }
    }

    private func allowedTypes() -> [UTType] {
        if case let .filePicker(options, _) = host.pending, !options.contentTypeIdentifiers.isEmpty {
            return options.contentTypeIdentifiers.compactMap { UTType($0) }
        }
        return [.data, .pdf, .image, .audio, .movie, .plainText]
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
private struct SharePresenter: ViewModifier {
    @Bindable var host: SwiftUIAgentHost

    func body(content: Content) -> some View {
        #if canImport(UIKit) && !os(watchOS) && !os(tvOS)
        content.sheet(isPresented: Binding(
            get: { if case .share = host.pending { return true } else { return false } },
            set: { if !$0 { host.resolveShare(succeeded: false) } }
        )) {
            if case let .share(items, _) = host.pending {
                AgentShareSheet(items: items) { ok in
                    host.resolveShare(succeeded: ok)
                }
            }
        }
        #else
        content
        #endif
    }
}

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
private struct ConfirmPresenter: ViewModifier {
    @Bindable var host: SwiftUIAgentHost

    func body(content: Content) -> some View {
        content.alert(
            title(),
            isPresented: Binding(
                get: { if case .confirm = host.pending { return true } else { return false } },
                set: { if !$0 { host.resolveConfirm(false) } }
            ),
            presenting: currentConfirm()
        ) { req in
            Button("Allow", role: req.isDestructive ? .destructive : nil) {
                host.resolveConfirm(true)
            }
            Button("Deny", role: .cancel) {
                host.resolveConfirm(false)
            }
        } message: { req in
            if let m = req.message { Text(m) }
        }
    }

    private func title() -> String {
        if case let .confirm(req) = host.pending { return req.title }
        return ""
    }

    private func currentConfirm() -> SwiftUIAgentHost.ConfirmRequest? {
        if case let .confirm(req) = host.pending { return req }
        return nil
    }
}
