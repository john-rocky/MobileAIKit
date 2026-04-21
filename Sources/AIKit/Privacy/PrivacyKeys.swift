import Foundation

/// Reference list of `Info.plist` usage-description keys that apps built on MobileAIKit
/// typically need. iOS *crashes* the first time a capability is used without its key,
/// so scaffolds should start from ``recommended`` and prune what they don't use.
///
/// Each entry pairs the plist key with a default justification string and the kit
/// surface that triggers the permission prompt.
public enum PrivacyKeys {
    public struct Entry: Sendable, Hashable {
        public let key: String
        public let suggestedValue: String
        /// MobileAIKit feature(s) that require this key.
        public let requiredBy: [String]
    }

    /// Camera — `AICameraCaptureView`, `AICameraAssistantView`, live Vision scanning.
    public static let camera = Entry(
        key: "NSCameraUsageDescription",
        suggestedValue: "Used to snap photos you ask the AI to analyze.",
        requiredBy: ["AICameraCaptureView", "AICameraAssistantView", "VisionKit DataScanner"]
    )

    /// Photo library read — `PhotosPicker`, `AICameraAssistantView`.
    public static let photoLibrary = Entry(
        key: "NSPhotoLibraryUsageDescription",
        suggestedValue: "Used to pick images you ask the AI to analyze.",
        requiredBy: ["PhotosPicker", "AICameraAssistantView"]
    )

    /// Photo library add — save generated or annotated images back to the library.
    public static let photoLibraryAdd = Entry(
        key: "NSPhotoLibraryAddUsageDescription",
        suggestedValue: "Used to save AI-annotated photos back to your library.",
        requiredBy: ["PhotosTools.save"]
    )

    /// Microphone — speech-to-text, voice assistant loop.
    public static let microphone = Entry(
        key: "NSMicrophoneUsageDescription",
        suggestedValue: "Used to capture your voice for on-device transcription.",
        requiredBy: ["VoiceAssistant", "AIVoiceAssistantView", "WhisperSpeechToText"]
    )

    /// Speech recognition — `SFSpeechRecognizer`.
    public static let speechRecognition = Entry(
        key: "NSSpeechRecognitionUsageDescription",
        suggestedValue: "Used to convert your speech to text on-device.",
        requiredBy: ["SpeechRecognizer", "AIKit.transcribe"]
    )

    /// HealthKit read — step count, existing nutrition totals.
    public static let healthRead = Entry(
        key: "NSHealthShareUsageDescription",
        suggestedValue: "Used to read your activity and nutrition data for personalized answers.",
        requiredBy: ["HealthKitBridge.requestReadAccess", "HealthKitBridge.dailyTotals"]
    )

    /// HealthKit write — save meals, water, and other nutrition samples.
    public static let healthWrite = Entry(
        key: "NSHealthUpdateUsageDescription",
        suggestedValue: "Used to save meals and nutrition you log to Apple Health.",
        requiredBy: ["HealthKitBridge.saveMeal", "HealthKitBridge.requestNutritionAuthorization"]
    )

    /// Contacts — `ContactsTools`.
    public static let contacts = Entry(
        key: "NSContactsUsageDescription",
        suggestedValue: "Used to find and update people you mention.",
        requiredBy: ["ContactsTools"]
    )

    /// Calendar — `EventKitTools`.
    public static let calendar = Entry(
        key: "NSCalendarsUsageDescription",
        suggestedValue: "Used to create events you ask the AI to schedule.",
        requiredBy: ["EventKitBridge"]
    )

    /// Reminders — `EventKitTools`.
    public static let reminders = Entry(
        key: "NSRemindersUsageDescription",
        suggestedValue: "Used to create reminders you ask the AI to schedule.",
        requiredBy: ["EventKitBridge"]
    )

    /// Location when-in-use — `LocationTools`, Weather/Maps queries.
    public static let locationWhenInUse = Entry(
        key: "NSLocationWhenInUseUsageDescription",
        suggestedValue: "Used to answer questions that depend on where you are.",
        requiredBy: ["LocationTools", "WeatherKitTools", "MapKitTools"]
    )

    /// Motion & fitness — `MotionTools`.
    public static let motion = Entry(
        key: "NSMotionUsageDescription",
        suggestedValue: "Used to summarize your activity.",
        requiredBy: ["MotionTools"]
    )

    /// Local network — discovery tools, on-device web servers.
    public static let localNetwork = Entry(
        key: "NSLocalNetworkUsageDescription",
        suggestedValue: "Used to reach local AI services on your network.",
        requiredBy: ["custom tools"]
    )

    /// Baseline every consumer app that uses camera + photos + voice needs.
    public static let recommendedCore: [Entry] = [
        .camera, .photoLibrary, .microphone, .speechRecognition
    ]

    /// Full reference — start here, delete what you don't use.
    public static let recommended: [Entry] = [
        .camera,
        .photoLibrary,
        .photoLibraryAdd,
        .microphone,
        .speechRecognition,
        .healthRead,
        .healthWrite,
        .contacts,
        .calendar,
        .reminders,
        .locationWhenInUse,
        .motion,
        .localNetwork
    ]

    /// `Info.plist`-shaped dictionary for quick pasting into xcodegen / tuist templates.
    public static func plistFragment(from entries: [Entry] = recommended) -> [String: String] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.suggestedValue) })
    }
}
