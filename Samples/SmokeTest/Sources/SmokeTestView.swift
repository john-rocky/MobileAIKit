import SwiftUI
import AIKit
import AIKitUI
import AIKitCoreMLLLM
import AIKitIntegration
import AIKitVision
#if canImport(UIKit)
import UIKit
#endif

/// End-to-end smoke test for the LocalAIKit public surface, pointed at the
/// bundled `CoreMLLLMBackend`. Every top-level helper we expose in docs gets
/// exercised here. The goal is: if this sample passes on a real device, the
/// kit's happy-path features all work with the shipped runtime.
///
/// What we deliberately do NOT test (because the simulator can't satisfy
/// them cleanly):
///   - Live mic capture (`SpeechToText.liveRecognition`) — needs user consent
///   - Real Apple Health writes (side effect, permission-gated)
///   - Camera capture (needs a physical camera)
/// Those are verified by the dedicated sample apps.
struct SmokeTestView: View {
    let backend: any AIBackend

    @State private var checks: [Check] = SmokeChecks.all
    @State private var runIndex: Int? = nil

    var body: some View {
        List {
            Section {
                Button {
                    Task { await runAll() }
                } label: {
                    Label(runIndex == nil ? "Run all checks" : "Running…", systemImage: "play.circle.fill")
                        .font(.headline)
                }
                .disabled(runIndex != nil)
            }
            Section("Checks") {
                ForEach(checks.indices, id: \.self) { i in
                    CheckRow(check: checks[i], active: runIndex == i)
                }
            }
        }
    }

    @MainActor
    private func runAll() async {
        for i in checks.indices { checks[i] = checks[i].resetting() }
        for i in checks.indices {
            runIndex = i
            let c = checks[i]
            let start = Date()
            do {
                let note = try await c.runner(backend)
                checks[i] = c.finished(.pass(note: note), elapsed: Date().timeIntervalSince(start))
            } catch {
                let msg = (error as? AIError)?.errorDescription ?? error.localizedDescription
                checks[i] = c.finished(.fail(msg), elapsed: Date().timeIntervalSince(start))
            }
        }
        runIndex = nil
    }
}

// MARK: - Check model

struct Check: Identifiable {
    enum Status { case pending, pass(note: String), fail(String) }
    let id = UUID()
    let name: String
    let detail: String
    let runner: @Sendable (any AIBackend) async throws -> String
    var status: Status = .pending
    var elapsedSeconds: Double? = nil

    func resetting() -> Check {
        var copy = self; copy.status = .pending; copy.elapsedSeconds = nil; return copy
    }
    func finished(_ s: Status, elapsed: Double) -> Check {
        var copy = self; copy.status = s; copy.elapsedSeconds = elapsed; return copy
    }
}

struct CheckRow: View {
    let check: Check
    let active: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                icon
                Text(check.name).font(.subheadline).bold()
                Spacer()
                if let e = check.elapsedSeconds {
                    Text(String(format: "%.1fs", e)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(check.detail).font(.caption).foregroundStyle(.secondary)
            if case .pass(let note) = check.status, !note.isEmpty {
                Text(note).font(.caption).foregroundStyle(.green)
                    .lineLimit(3)
            }
            if case .fail(let msg) = check.status {
                Text(msg).font(.caption).foregroundStyle(.red)
                    .lineLimit(5)
            }
        }
        .padding(.vertical, 2)
    }
    @ViewBuilder private var icon: some View {
        switch check.status {
        case .pending:
            if active { ProgressView().scaleEffect(0.7) }
            else { Image(systemName: "circle").foregroundStyle(.secondary) }
        case .pass: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .fail: Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }
}
