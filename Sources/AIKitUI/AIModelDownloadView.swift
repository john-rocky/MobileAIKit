import SwiftUI
import AIKit

@available(iOS 17.0, macOS 14.0, visionOS 1.0, *)
public struct AIModelDownloadView: View {
    public let descriptor: ModelDescriptor
    public let downloader: ModelDownloader
    public let onReady: (URL) -> Void

    @State private var progress: DownloadProgress?
    @State private var error: String?
    @State private var ready: URL?
    @State private var isDownloading: Bool = false

    public init(
        descriptor: ModelDescriptor,
        downloader: ModelDownloader = ModelDownloader(),
        onReady: @escaping (URL) -> Void
    ) {
        self.descriptor = descriptor
        self.downloader = downloader
        self.onReady = onReady
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(descriptor.displayName).font(.title2).bold()
            HStack(spacing: 6) {
                Text(descriptor.version)
                if let size = expectedSizeLabel {
                    Text("·").foregroundStyle(.tertiary)
                    Label(size, systemImage: "externaldrive")
                }
                if descriptor.modality == .vision {
                    Text("·").foregroundStyle(.tertiary)
                    Label("Vision model", systemImage: "eye")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if isDownloading || progress != nil {
                if let progress {
                    ProgressView(value: progress.fraction) {
                        Text("\(progress.file)")
                            .font(.footnote)
                            .monospaced()
                    }
                    Text("\(formatBytes(progress.overallBytesDownloaded)) / \(formatBytes(progress.overallTotalBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if ready == nil, let size = expectedSizeLabel {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Downloads \(size) over Wi-Fi", systemImage: "wifi")
                        .font(.footnote)
                    Label("First-run warm-up may take 10–30 s on ANE", systemImage: "clock")
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
            }

            if let error {
                Text(error).foregroundStyle(.red)
            }

            HStack {
                if ready == nil {
                    Button(isDownloading ? "Downloading…" : downloadLabel) {
                        Task { await start() }
                    }
                    .disabled(isDownloading)
                    .buttonStyle(.borderedProminent)
                } else {
                    Label("Ready", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    Button("Use") { if let r = ready { onReady(r) } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }

    private var expectedTotalBytes: Int64 {
        descriptor.files.reduce(0) { $0 + ($1.expectedBytes ?? 0) }
    }

    private var expectedSizeLabel: String? {
        let total = expectedTotalBytes
        return total > 0 ? formatBytes(total) : nil
    }

    private var downloadLabel: String {
        if let size = expectedSizeLabel { return "Download (\(size))" }
        return "Download"
    }

    private func start() async {
        isDownloading = true
        error = nil
        do {
            let url = try await downloader.ensure(descriptor) { p in
                Task { @MainActor in self.progress = p }
            }
            ready = url
            onReady(url)
        } catch {
            self.error = error.localizedDescription
        }
        isDownloading = false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
