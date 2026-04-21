import Foundation
import AIKit
#if canImport(CoreNFC) && os(iOS)
import CoreNFC

public final class NFCReaderBridge: NSObject, @unchecked Sendable, NFCNDEFReaderSessionDelegate {
    private var continuation: CheckedContinuation<[NFCNDEFMessage], Error>?

    public override init() { super.init() }

    public func readSingleTag(alertMessage: String = "Hold your phone near the NFC tag") async throws -> [NFCNDEFMessage] {
        guard NFCNDEFReaderSession.readingAvailable else {
            throw AIError.unsupportedCapability("NFC not available")
        }
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
            session.alertMessage = alertMessage
            session.begin()
        }
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        continuation?.resume(returning: messages)
        continuation = nil
    }

    public func scanNFCTool() -> any Tool {
        let spec = ToolSpec(
            name: "scan_nfc_tag",
            description: "Read an NDEF NFC tag and return its payloads as text.",
            parameters: .object(properties: [:], required: []),
            requiresApproval: true,
            sideEffectFree: true
        )
        struct Args: Decodable {}
        struct Record: Encodable { let type: String; let text: String }
        return TypedTool(spec: spec) { (_: Args) async throws -> [Record] in
            let messages = try await self.readSingleTag()
            return messages.flatMap { msg in
                msg.records.map { r in
                    Record(
                        type: String(data: r.type, encoding: .utf8) ?? "?",
                        text: String(data: r.payload, encoding: .utf8) ?? r.payload.base64EncodedString()
                    )
                }
            }
        }
    }
}
#endif
