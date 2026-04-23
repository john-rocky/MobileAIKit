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
    @State private var gemma3Checks: [Check] = SmokeChecks.gemma3
    @State private var mainRunning = false
    @State private var gemma3Running = false
    @State private var mainIndex: Int? = nil
    @State private var gemma3Index: Int? = nil

    private var anyRunning: Bool { mainRunning || gemma3Running }

    var body: some View {
        List {
            Section {
                Button {
                    Task { await runAll() }
                } label: {
                    Label(mainRunning ? "Running…" : "Run all checks", systemImage: "play.circle.fill")
                        .font(.headline)
                }
                .disabled(anyRunning)
            }
            Section("Checks") {
                ForEach(checks.indices, id: \.self) { i in
                    CheckRow(check: checks[i], active: mainIndex == i)
                }
            }

            Section {
                Button {
                    Task { await runGemma3() }
                } label: {
                    Label(gemma3Running ? "Running…" : "Run Gemma 3 checks", systemImage: "play.circle")
                        .font(.headline)
                }
                .disabled(anyRunning)
                Text("Opt-in. First run downloads ~420 MB FunctionGemma + ~295 MB EmbeddingGemma to Documents/LocalAIKit/models, then caches for subsequent runs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Gemma 3 specialists") {
                ForEach(gemma3Checks.indices, id: \.self) { i in
                    CheckRow(check: gemma3Checks[i], active: gemma3Index == i)
                }
            }
        }
    }

    @MainActor
    private func runAll() async {
        mainRunning = true
        defer { mainRunning = false; mainIndex = nil }
        for i in checks.indices { checks[i] = checks[i].resetting() }
        for i in checks.indices {
            mainIndex = i
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
    }

    @MainActor
    private func runGemma3() async {
        gemma3Running = true
        defer { gemma3Running = false; gemma3Index = nil }
        for i in gemma3Checks.indices { gemma3Checks[i] = gemma3Checks[i].resetting() }
        for i in gemma3Checks.indices {
            gemma3Index = i
            let c = gemma3Checks[i]
            let start = Date()
            do {
                let note = try await c.runner(backend)
                gemma3Checks[i] = c.finished(.pass(note: note), elapsed: Date().timeIntervalSince(start))
            } catch {
                let msg = (error as? AIError)?.errorDescription ?? error.localizedDescription
                gemma3Checks[i] = c.finished(.fail(msg), elapsed: Date().timeIntervalSince(start))
            }
        }
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
