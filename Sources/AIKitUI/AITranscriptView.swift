import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AITranscriptView: View {
    public struct Segment: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let speaker: String
        public let text: String
        public let startTime: Double
        public let duration: Double
        public init(speaker: String, text: String, startTime: Double, duration: Double) {
            self.speaker = speaker
            self.text = text
            self.startTime = startTime
            self.duration = duration
        }
    }

    public let segments: [Segment]

    public init(segments: [Segment]) {
        self.segments = segments
    }

    public var body: some View {
        List(segments) { segment in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(segment.speaker).font(.caption).bold().foregroundStyle(.tint)
                    Spacer()
                    Text(formatTime(segment.startTime)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
                Text(segment.text).textSelection(.enabled)
            }
        }
    }

    private func formatTime(_ t: Double) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
