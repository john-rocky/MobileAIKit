import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIApprovalSheet: View {
    public let spec: ToolSpec
    public let arguments: String
    public let onDecision: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    public init(spec: ToolSpec, arguments: String, onDecision: @escaping (Bool) -> Void) {
        self.spec = spec
        self.arguments = arguments
        self.onDecision = onDecision
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(spec.name).font(.title2).bold()
                Text(spec.description).font(.body)
                GroupBox("Arguments") {
                    ScrollView {
                        Text(arguments).monospaced().textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if !spec.sideEffectFree {
                    Label("Has side effects", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Spacer()
                HStack {
                    Button("Deny", role: .destructive) {
                        onDecision(false); dismiss()
                    }
                    Button("Allow") {
                        onDecision(true); dismiss()
                    }.buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Tool approval")
        }
    }
}
