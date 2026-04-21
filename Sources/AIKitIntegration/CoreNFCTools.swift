import Foundation
import AIKit
#if canImport(CoreNFC) && os(iOS)
@preconcurrency import CoreNFC

/// Sendable snapshot of an NDEF record — `NFCNDEFMessage` / `NFCNDEFPayload`
/// aren't Sendable, so extracting the bytes on the delegate queue lets the
/// value cross the continuation boundary safely.
public struct NDEFRecordSnapshot: Sendable, Hashable {
    public let typeName: String
    public let payload: Data
    public init(typeName: String, payload: Data) {
        self.typeName = typeName
        self.payload = payload
    }
}

public final class NFCReaderBridge: NSObject, @unchecked Sendable, NFCNDEFReaderSessionDelegate {
    private var continuation: CheckedContinuation<[NDEFRecordSnapshot], Error>?

    public override init() { super.init() }

    public func readSingleTag(alertMessage: String = "Hold your phone near the NFC tag") async throws -> [NDEFRecordSnapshot] {
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
        let snapshots = messages.flatMap { msg in
            msg.records.map { record in
                NDEFRecordSnapshot(
                    typeName: String(data: record.type, encoding: .utf8) ?? "?",
                    payload: record.payload
                )
            }
        }
        continuation?.resume(returning: snapshots)
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
            let records = try await self.readSingleTag()
            return records.map { r in
                Record(
                    type: r.typeName,
                    text: String(data: r.payload, encoding: .utf8) ?? r.payload.base64EncodedString()
                )
            }
        }
    }
}
#endif
