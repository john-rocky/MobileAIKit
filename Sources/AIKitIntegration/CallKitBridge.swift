import Foundation
import AIKit
#if canImport(CallKit) && os(iOS)
import CallKit

public final class CallKitBridge: NSObject, @unchecked Sendable, CXProviderDelegate {
    public let provider: CXProvider
    public let controller = CXCallController()

    public init(localizedName: String = "LocalAIKit") {
        let config = CXProviderConfiguration()
        config.supportsVideo = false
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        self.provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    public func reportIncoming(uuid: UUID = UUID(), handle: String) async throws {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            provider.reportNewIncomingCall(with: uuid, update: update) { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
    }

    public func startOutgoing(uuid: UUID = UUID(), handle: String) async throws {
        let h = CXHandle(type: .generic, value: handle)
        let action = CXStartCallAction(call: uuid, handle: h)
        let txn = CXTransaction(action: action)
        try await controller.request(txn)
    }

    public func end(uuid: UUID) async throws {
        let action = CXEndCallAction(call: uuid)
        try await controller.request(CXTransaction(action: action))
    }

    public func providerDidReset(_ provider: CXProvider) {}
}
#endif
