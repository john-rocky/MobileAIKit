import Foundation
import AIKit
#if canImport(AVFoundation)
import AVFoundation
#endif

@MainActor
public extension AIAgent {
    /// Register a `speak` tool that reads text aloud via `AVSpeechSynthesizer`.
    func registerSpeechTools() async {
        #if canImport(AVFoundation)
        await addTools([Self.makeSpeakTool()])
        #endif
    }

    #if canImport(AVFoundation)
    private static func makeSpeakTool() -> any Tool {
        let spec = ToolSpec(
            name: "speak",
            description: "Read text aloud on-device. Useful for hands-free assistant style responses. Non-blocking.",
            parameters: .object(
                properties: [
                    "text": .string(description: "What to say."),
                    "locale": .string(description: "BCP-47 locale like 'en-US' or 'ja-JP'.")
                ],
                required: ["text"]
            ),
            sideEffectFree: false
        )
        struct Args: Decodable { let text: String; let locale: String? }
        struct Out: Encodable { let spoken: Bool }
        return TypedTool(spec: spec) { (args: Args) async throws -> Out in
            let locale = args.locale.map(Locale.init(identifier:)) ?? Locale(identifier: "en-US")
            Task { @MainActor in
                await AIKit.speak(args.text, locale: locale)
            }
            return Out(spoken: true)
        }
    }
    #endif
}
