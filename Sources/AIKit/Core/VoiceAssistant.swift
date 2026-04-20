import Foundation

public enum VoiceAssistantEvent: Sendable {
    case listening
    case partialTranscript(String)
    case finalTranscript(String)
    case thinking
    case partialAnswer(String)
    case finalAnswer(String)
    case speaking
    case idle
    case error(String)
}

public protocol VoiceTranscriber: Sendable {
    func requestAuthorization() async -> Bool
    func live() throws -> AsyncThrowingStream<VoiceTranscriberResult, Error>
    func stop()
}

public struct VoiceTranscriberResult: Sendable {
    public let text: String
    public let isFinal: Bool
    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}

public protocol VoiceSpeaker: Sendable {
    func speak(_ text: String) async
    func stop()
}

@MainActor
@Observable
public final class VoiceAssistant {
    public let backend: any AIBackend
    public let transcriber: any VoiceTranscriber
    public let speaker: any VoiceSpeaker
    public var systemPrompt: String?
    public var config: GenerationConfig

    public private(set) var events: [VoiceAssistantEvent] = []
    public private(set) var isRunning: Bool = false
    public var tools: [ToolSpec] = []
    public var toolRegistry: ToolRegistry?

    public init(
        backend: any AIBackend,
        transcriber: any VoiceTranscriber,
        speaker: any VoiceSpeaker,
        systemPrompt: String? = nil,
        config: GenerationConfig = .default
    ) {
        self.backend = backend
        self.transcriber = transcriber
        self.speaker = speaker
        self.systemPrompt = systemPrompt
        self.config = config
    }

    public func run() -> AsyncThrowingStream<VoiceAssistantEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
                self.isRunning = true
                defer { self.isRunning = false }

                do {
                    let granted = await self.transcriber.requestAuthorization()
                    guard granted else {
                        continuation.yield(.error("Speech authorization denied"))
                        continuation.finish()
                        return
                    }

                    while !Task.isCancelled {
                        continuation.yield(.listening)
                        self.events.append(.listening)

                        var final: String?
                        let transcriptStream = try self.transcriber.live()
                        for try await item in transcriptStream {
                            if Task.isCancelled { break }
                            if item.isFinal {
                                final = item.text
                                continuation.yield(.finalTranscript(item.text))
                                self.events.append(.finalTranscript(item.text))
                                break
                            } else {
                                continuation.yield(.partialTranscript(item.text))
                            }
                        }
                        self.transcriber.stop()
                        guard let question = final, !question.isEmpty else { continue }

                        continuation.yield(.thinking)
                        self.events.append(.thinking)
                        var messages: [Message] = []
                        if let systemPrompt = self.systemPrompt { messages.append(.system(systemPrompt)) }
                        messages.append(.user(question))

                        var accumulated = ""
                        for try await chunk in self.backend.stream(messages: messages, tools: self.tools, config: self.config) {
                            accumulated += chunk.delta
                            if !chunk.delta.isEmpty {
                                continuation.yield(.partialAnswer(accumulated))
                            }
                            if chunk.finished { break }
                        }

                        continuation.yield(.finalAnswer(accumulated))
                        self.events.append(.finalAnswer(accumulated))

                        continuation.yield(.speaking)
                        await self.speaker.speak(accumulated)

                        continuation.yield(.idle)
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func stop() {
        transcriber.stop()
        speaker.stop()
        isRunning = false
    }
}
