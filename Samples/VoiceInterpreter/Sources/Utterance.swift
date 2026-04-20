import Foundation

enum Speaker: String, Codable, Hashable {
    case a = "A"
    case b = "B"
}

struct Utterance: Identifiable, Hashable, Codable {
    let id: UUID
    let speaker: Speaker
    let sourceLocale: String
    let targetLocale: String
    let original: String
    let translation: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        speaker: Speaker,
        sourceLocale: String,
        targetLocale: String,
        original: String,
        translation: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.speaker = speaker
        self.sourceLocale = sourceLocale
        self.targetLocale = targetLocale
        self.original = original
        self.translation = translation
        self.createdAt = createdAt
    }
}

struct LanguagePair: Hashable {
    var locale: Locale
    var displayName: String

    static let presets: [LanguagePair] = [
        .init(locale: Locale(identifier: "en-US"), displayName: "English"),
        .init(locale: Locale(identifier: "ja-JP"), displayName: "日本語"),
        .init(locale: Locale(identifier: "zh-CN"), displayName: "中文"),
        .init(locale: Locale(identifier: "ko-KR"), displayName: "한국어"),
        .init(locale: Locale(identifier: "es-ES"), displayName: "Español"),
        .init(locale: Locale(identifier: "fr-FR"), displayName: "Français"),
        .init(locale: Locale(identifier: "de-DE"), displayName: "Deutsch"),
        .init(locale: Locale(identifier: "pt-BR"), displayName: "Português"),
        .init(locale: Locale(identifier: "it-IT"), displayName: "Italiano"),
        .init(locale: Locale(identifier: "hi-IN"), displayName: "हिन्दी"),
        .init(locale: Locale(identifier: "ar-SA"), displayName: "العربية")
    ]
}
