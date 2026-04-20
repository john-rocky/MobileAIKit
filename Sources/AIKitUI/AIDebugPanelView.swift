import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIDebugPanelView: View {
    public let telemetry: Telemetry

    @State private var events: [TelemetryEvent] = []

    public init(telemetry: Telemetry) { self.telemetry = telemetry }

    public var body: some View {
        List(events.reversed(), id: \.self) { event in
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name).font(.headline)
                HStack {
                    if let d = event.duration {
                        Text(String(format: "%.3fs", d)).foregroundStyle(.secondary).font(.caption)
                    }
                    Spacer()
                    Text(event.timestamp, style: .time).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(event.metadata.keys.sorted(), id: \.self) { key in
                    if let v = event.metadata[key] {
                        Text("\(key): \(v)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            events = await telemetry.export()
        }
        .refreshable {
            events = await telemetry.export()
        }
        .navigationTitle("Telemetry")
    }
}
