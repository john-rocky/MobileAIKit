import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AISettingsView: View {
    @State private var quality: QualityProfile = .balanced
    @State private var thermalAware: Bool = true
    @State private var usedBytes: Int64 = 0
    @State private var deviceClass: DeviceClass = .midTier

    public init() {}

    public var body: some View {
        Form {
            Section("Performance") {
                Picker("Quality profile", selection: $quality) {
                    Text("High quality").tag(QualityProfile.highQuality)
                    Text("Balanced").tag(QualityProfile.balanced)
                    Text("Fast").tag(QualityProfile.fast)
                    Text("Ultra fast").tag(QualityProfile.ultraFast)
                }
                Toggle("Thermal-aware degradation", isOn: $thermalAware)
            }
            Section("Device") {
                LabeledContent("Device class", value: deviceClass.rawValue)
            }
            Section("Models on disk") {
                LabeledContent("Used", value: ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file))
            }
        }
        .onChange(of: quality) { _, newValue in
            Task { await ResourceGovernor.shared.setPreferredProfile(newValue) }
        }
        .onChange(of: thermalAware) { _, newValue in
            Task { await ResourceGovernor.shared.setThermalDegradation(newValue) }
        }
        .task { await refresh() }
        .navigationTitle("AI Settings")
    }

    private func refresh() async {
        let gov = ResourceGovernor.shared
        quality = await gov.preferredProfile
        thermalAware = await gov.thermalDegradationEnabled
        deviceClass = await gov.deviceClass()
        usedBytes = await ModelCache.shared.totalUsedBytes()
    }
}

public extension ResourceGovernor {
    func setPreferredProfile(_ profile: QualityProfile) async {
        self.preferredProfile = profile
    }

    func setThermalDegradation(_ enabled: Bool) async {
        self.thermalDegradationEnabled = enabled
    }
}
