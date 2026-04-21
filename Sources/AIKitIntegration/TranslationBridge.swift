import Foundation
import AIKit
#if canImport(Translation)
import Translation
import SwiftUI
#endif

#if canImport(Translation)
/// Thin wrapper over Apple's on-device **Translation** framework (iOS 17.4+).
///
/// Use this when you want Apple's first-party translation alongside Gemma 4's
/// `AIKit.translate` — same API, different model.
@available(iOS 17.4, macOS 14.4, *)
public enum AppleTranslation {
    /// Fire-and-forget translation via a hosting view. Requires a view context.
    @MainActor
    public struct TranslatingView: View {
        let text: String
        @Binding var output: String
        @State private var configuration: TranslationSession.Configuration?

        public init(text: String, output: Binding<String>) {
            self.text = text
            self._output = output
        }

        public var body: some View {
            Color.clear
                .translationTask(configuration) { session in
                    do {
                        let response = try await session.translate(text)
                        output = response.targetText
                    } catch {
                        output = "Translation failed: \(error.localizedDescription)"
                    }
                }
                .onAppear { configuration = .init() }
        }
    }

    /// SwiftUI-only helper that presents a system translation sheet over any view.
    public struct TranslationPresenter: ViewModifier {
        let text: String
        @Binding var isPresented: Bool

        public func body(content: Content) -> some View {
            content.translationPresentation(isPresented: $isPresented, text: text)
        }
    }
}

@available(iOS 17.4, macOS 14.4, *)
public extension View {
    func appleTranslationSheet(text: String, isPresented: Binding<Bool>) -> some View {
        modifier(AppleTranslation.TranslationPresenter(text: text, isPresented: isPresented))
    }
}
#endif
