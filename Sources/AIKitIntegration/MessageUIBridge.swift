import Foundation
import AIKit
#if canImport(MessageUI) && os(iOS)
import MessageUI
import SwiftUI

public struct ComposeEmailView: UIViewControllerRepresentable {
    public let recipients: [String]
    public let subject: String
    public let body: String
    public let onFinish: (Result<MFMailComposeResult, Error>) -> Void

    public init(
        recipients: [String],
        subject: String,
        body: String,
        onFinish: @escaping (Result<MFMailComposeResult, Error>) -> Void
    ) {
        self.recipients = recipients
        self.subject = subject
        self.body = body
        self.onFinish = onFinish
    }

    public func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    public func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    public func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    @MainActor
    public final class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        let onFinish: (Result<MFMailComposeResult, Error>) -> Void
        init(onFinish: @escaping (Result<MFMailComposeResult, Error>) -> Void) { self.onFinish = onFinish }
        public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error { onFinish(.failure(error)) } else { onFinish(.success(result)) }
            controller.dismiss(animated: true)
        }
    }
}

public struct ComposeSMSView: UIViewControllerRepresentable {
    public let recipients: [String]
    public let body: String
    public let onFinish: (MessageComposeResult) -> Void

    public init(
        recipients: [String],
        body: String,
        onFinish: @escaping (MessageComposeResult) -> Void
    ) {
        self.recipients = recipients
        self.body = body
        self.onFinish = onFinish
    }

    public func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    public func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    public func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}

    @MainActor
    public final class Coordinator: NSObject, @preconcurrency MFMessageComposeViewControllerDelegate {
        let onFinish: (MessageComposeResult) -> Void
        init(onFinish: @escaping (MessageComposeResult) -> Void) { self.onFinish = onFinish }
        public func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            onFinish(result)
            controller.dismiss(animated: true)
        }
    }
}
#endif
