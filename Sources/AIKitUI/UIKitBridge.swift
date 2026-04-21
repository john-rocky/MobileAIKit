import SwiftUI
import AIKit
#if canImport(UIKit) && !os(watchOS)
import UIKit

/// Wrap any SwiftUI view from AIKitUI into a `UIViewController`.
///
/// ```swift
/// let session = ChatSession(backend: backend)
/// let vc = AIHostingController.chat(session: session)
/// navigationController.pushViewController(vc, animated: true)
/// ```
@available(iOS 17.0, visionOS 1.0, *)
public enum AIHostingController {
    public static func chat(session: ChatSession) -> UIViewController {
        UIHostingController(rootView: AIChatView(session: session))
    }

    public static func playground(backend: any AIBackend) -> UIViewController {
        UIHostingController(rootView: AIPromptPlaygroundView(backend: backend))
    }

    public static func documentQA(backend: any AIBackend, pipeline: RAGPipeline) -> UIViewController {
        UIHostingController(rootView: AIDocumentQAView(backend: backend, pipeline: pipeline))
    }

    public static func voiceAssistant(assistant: VoiceAssistant) -> UIViewController {
        UIHostingController(rootView: AIVoiceAssistantView(assistant: assistant))
    }

    public static func cameraAssistant(backend: any AIBackend) -> UIViewController {
        UIHostingController(rootView: AICameraAssistantView(backend: backend))
    }

    public static func modelDownload(descriptor: ModelDescriptor, onReady: @escaping @Sendable (URL) -> Void) -> UIViewController {
        UIHostingController(rootView: AIModelDownloadView(descriptor: descriptor, onReady: onReady))
    }

    public static func prefabGallery(backend: any AIBackend) -> UIViewController {
        UIHostingController(rootView: AIPrefabGallery(backend: backend))
    }

    public static func debugPanel(telemetry: Telemetry) -> UIViewController {
        UIHostingController(rootView: AIDebugPanelView(telemetry: telemetry))
    }
}

/// Storyboard-friendly container that embeds the SwiftUI chat view.
@available(iOS 17.0, visionOS 1.0, *)
public final class AIChatContainerViewController: UIViewController {
    public let session: ChatSession
    private let hosting: UIHostingController<AIChatView>

    public init(session: ChatSession) {
        self.session = session
        self.hosting = UIHostingController(rootView: AIChatView(session: session))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(session:)")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
    }
}
#endif
