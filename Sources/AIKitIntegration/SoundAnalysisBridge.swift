import Foundation
import AIKit
#if canImport(SoundAnalysis)
import SoundAnalysis
import AVFoundation

public final class SoundAnalysisBridge: NSObject, @unchecked Sendable {
    public let classifier: SNClassifier?
    public let request: SNClassifySoundRequest

    public override init() {
        if #available(iOS 15.0, macOS 12.0, *) {
            let version = SNClassifierIdentifier.version1
            self.request = (try? SNClassifySoundRequest(classifierIdentifier: version))
                ?? SNClassifySoundRequest(mlModel: MLModel.dummy())
        } else {
            self.request = SNClassifySoundRequest(mlModel: MLModel.dummy())
        }
        self.classifier = nil
    }

    public func classify(audio: AudioAttachment, window: Double = 1.5) async throws -> [SoundClassification] {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("sound-\(UUID().uuidString).wav")
        try audio.loadData().write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try await classify(fileURL: tmp, window: window)
    }

    public func classify(fileURL: URL, window: Double = 1.5) async throws -> [SoundClassification] {
        return try await withCheckedThrowingContinuation { cont in
            do {
                let analyzer = try SNAudioFileAnalyzer(url: fileURL)
                let req = request
                req.windowDuration = CMTime(seconds: window, preferredTimescale: 48_000)
                req.overlapFactor = 0.5
                let observer = Observer()
                try analyzer.add(req, withObserver: observer)
                observer.completion = { results in cont.resume(returning: results) }
                observer.failure = { error in cont.resume(throwing: error) }
                analyzer.analyze()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    final class Observer: NSObject, SNResultsObserving {
        var items: [SoundClassification] = []
        var completion: (([SoundClassification]) -> Void)?
        var failure: ((Error) -> Void)?

        func request(_ request: SNRequest, didProduce result: SNResult) {
            guard let r = result as? SNClassificationResult else { return }
            for c in r.classifications.prefix(3) {
                items.append(SoundClassification(identifier: c.identifier, confidence: Float(c.confidence), timeSeconds: r.timeRange.start.seconds))
            }
        }

        func request(_ request: SNRequest, didFailWithError error: Error) { failure?(error) }
        func requestDidComplete(_ request: SNRequest) { completion?(items) }
    }

    public func classifyAudioTool() -> any Tool {
        let spec = ToolSpec(
            name: "classify_ambient_sound",
            description: "Classify sounds in an audio file (bark, speech, music, alarm, etc.).",
            parameters: .object(
                properties: ["file_path": .string()],
                required: ["file_path"]
            ),
            sideEffectFree: true
        )
        struct Args: Decodable { let file_path: String }
        return TypedTool(spec: spec) { (args: Args) async throws -> [SoundClassification] in
            try await self.classify(fileURL: URL(fileURLWithPath: args.file_path))
        }
    }
}

public struct SoundClassification: Sendable, Hashable, Codable {
    public let identifier: String
    public let confidence: Float
    public let timeSeconds: Double
}

private extension MLModel {
    static func dummy() -> MLModel {
        let url = URL(fileURLWithPath: "/dev/null")
        return (try? MLModel(contentsOf: url)) ?? MLModel()
    }
}
#endif
