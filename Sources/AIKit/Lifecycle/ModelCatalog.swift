import Foundation

/// Curated list of on-device-friendly local models with URLs that `HFModelDownloader` can fetch.
///
/// Entries are Q4_K_M GGUF quantisations — useful as metadata for your own
/// runtime integration. LocalAIKit itself only ships the `CoreMLLLMBackend`;
/// see `CoreMLLLMBackend.availableModels` (in `AIKitCoreMLLLM`) for the built-in
/// CoreML-LLM catalog.
public enum ModelCatalog {

    // MARK: GGUF metadata

    /// Gemma 4 E2B Instruct (Apr 2026). Effective 2B via Per-Layer Embeddings.
    /// Multimodal: text + image + audio inputs on-device.
    public static let gemma4_e2b_Q4 = ModelDescriptor(
        name: "gemma-4-e2b-it",
        version: "q4_k_m",
        format: .gguf,
        modality: .vision,
        contextLength: 131_072,
        files: [ModelFile(
            relativePath: "gemma-4-e2b-it-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/google/gemma-4-e2b-it-gguf/resolve/main/gemma-4-e2b-it-Q4_K_M.gguf")!
        )],
        displayName: "Gemma 4 E2B IT (Q4_K_M, multimodal)",
        minRAMBytes: 2_500_000_000
    )

    /// Gemma 4 E4B Instruct (Apr 2026). Effective 4B, best-in-class on-device multimodal.
    public static let gemma4_e4b_Q4 = ModelDescriptor(
        name: "gemma-4-e4b-it",
        version: "q4_k_m",
        format: .gguf,
        modality: .vision,
        contextLength: 131_072,
        files: [ModelFile(
            relativePath: "gemma-4-e4b-it-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/google/gemma-4-e4b-it-gguf/resolve/main/gemma-4-e4b-it-Q4_K_M.gguf")!
        )],
        displayName: "Gemma 4 E4B IT (Q4_K_M, multimodal)",
        minRAMBytes: 5_000_000_000
    )

    /// Gemma 4 26B MoE Instruct (Apr 2026). Mac / high-end only.
    public static let gemma4_26b_moe_Q4 = ModelDescriptor(
        name: "gemma-4-26b-moe-it",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 131_072,
        files: [ModelFile(
            relativePath: "gemma-4-26b-moe-it-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/bartowski/gemma-4-26b-moe-it-GGUF/resolve/main/gemma-4-26b-moe-it-Q4_K_M.gguf")!
        )],
        displayName: "Gemma 4 26B MoE IT (Q4_K_M)",
        minRAMBytes: 20_000_000_000
    )

    /// Gemma 4 31B Dense Instruct (Apr 2026). Server-grade quality locally on Mac Studio / high-RAM Macs.
    public static let gemma4_31b_dense_Q4 = ModelDescriptor(
        name: "gemma-4-31b-it",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 131_072,
        files: [ModelFile(
            relativePath: "gemma-4-31b-it-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/bartowski/gemma-4-31b-it-GGUF/resolve/main/gemma-4-31b-it-Q4_K_M.gguf")!
        )],
        displayName: "Gemma 4 31B Dense IT (Q4_K_M)",
        minRAMBytes: 24_000_000_000
    )

    /// Qwen 3 0.6B Instruct (Apr 2025). Smallest good general-purpose local model.
    public static let qwen3_0_6B_Q4 = ModelDescriptor(
        name: "qwen3-0.6b",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 32_768,
        files: [ModelFile(
            relativePath: "Qwen3-0.6B-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf")!
        )],
        displayName: "Qwen 3 0.6B (Q4_K_M)",
        minRAMBytes: 1_000_000_000
    )

    /// Qwen 3 1.7B Instruct (Apr 2025). Sweet spot for mid-tier iPhones.
    public static let qwen3_1_7B_Q4 = ModelDescriptor(
        name: "qwen3-1.7b",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 32_768,
        files: [ModelFile(
            relativePath: "Qwen3-1.7B-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf")!
        )],
        displayName: "Qwen 3 1.7B (Q4_K_M)",
        minRAMBytes: 2_500_000_000
    )

    /// Qwen 3 4B Instruct (Apr 2025). Strong quality, iPhone 16 Pro+ recommended.
    public static let qwen3_4B_Q4 = ModelDescriptor(
        name: "qwen3-4b",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 32_768,
        files: [ModelFile(
            relativePath: "Qwen3-4B-Instruct-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/bartowski/Qwen3-4B-Instruct-GGUF/resolve/main/Qwen3-4B-Instruct-Q4_K_M.gguf")!
        )],
        displayName: "Qwen 3 4B Instruct (Q4_K_M)",
        minRAMBytes: 5_000_000_000
    )

    /// Gemma 3 1B Instruct (Mar 2025).
    public static let gemma3_1B_Q4 = ModelDescriptor(
        name: "gemma-3-1b-it",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 32_768,
        files: [ModelFile(
            relativePath: "gemma-3-1b-it-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/bartowski/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf")!
        )],
        displayName: "Gemma 3 1B Instruct (Q4_K_M)",
        minRAMBytes: 2_000_000_000
    )

    /// Gemma 3 4B Instruct (Mar 2025). Multimodal-capable weights.
    public static let gemma3_4B_Q4 = ModelDescriptor(
        name: "gemma-3-4b-it",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 131_072,
        files: [ModelFile(
            relativePath: "gemma-3-4b-it-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/bartowski/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf")!
        )],
        displayName: "Gemma 3 4B Instruct (Q4_K_M)",
        minRAMBytes: 5_000_000_000
    )

    /// Phi-4 mini Instruct (Feb 2025, 3.8B). 128K context.
    public static let phi4_mini_Q4 = ModelDescriptor(
        name: "phi-4-mini-instruct",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 131_072,
        files: [ModelFile(
            relativePath: "Phi-4-mini-instruct-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/bartowski/Phi-4-mini-instruct-GGUF/resolve/main/Phi-4-mini-instruct-Q4_K_M.gguf")!
        )],
        displayName: "Phi-4 mini Instruct (Q4_K_M)",
        minRAMBytes: 4_500_000_000
    )

    /// SmolLM3 3B Instruct (2025). Strong tiny general-purpose model.
    public static let smollm3_3B_Q4 = ModelDescriptor(
        name: "smollm3-3b",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 65_536,
        files: [ModelFile(
            relativePath: "SmolLM3-3B-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/bartowski/SmolLM3-3B-GGUF/resolve/main/SmolLM3-3B-Q4_K_M.gguf")!
        )],
        displayName: "SmolLM3 3B (Q4_K_M)",
        minRAMBytes: 4_000_000_000
    )

    /// Mistral Small 3 Instruct (Jan 2025, 24B). Big; M-series Mac only.
    public static let mistralSmall3_24B_Q4 = ModelDescriptor(
        name: "mistral-small-3-instruct",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 32_768,
        files: [ModelFile(
            relativePath: "Mistral-Small-24B-Instruct-2501-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/bartowski/Mistral-Small-24B-Instruct-2501-GGUF/resolve/main/Mistral-Small-24B-Instruct-2501-Q4_K_M.gguf")!
        )],
        displayName: "Mistral Small 3 24B (Q4_K_M)",
        minRAMBytes: 18_000_000_000
    )

    /// Llama 3.2 1B — legacy but widely tested, still useful on low-tier iPhones.
    public static let llama3_2_1B_Q4 = ModelDescriptor(
        name: "llama-3.2-1b-instruct",
        version: "q4_k_m",
        format: .gguf,
        contextLength: 131_072,
        files: [ModelFile(
            relativePath: "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
            url: URL(string: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf")!
        )],
        displayName: "Llama 3.2 1B Instruct (legacy)",
        minRAMBytes: 2_000_000_000
    )

    // MARK: Grouped lists

    public static let allText: [ModelDescriptor] = [
        gemma4_e2b_Q4,
        gemma4_e4b_Q4,
        gemma4_26b_moe_Q4,
        gemma4_31b_dense_Q4,
        qwen3_0_6B_Q4,
        qwen3_1_7B_Q4,
        qwen3_4B_Q4,
        gemma3_1B_Q4,
        gemma3_4B_Q4,
        phi4_mini_Q4,
        smollm3_3B_Q4,
        llama3_2_1B_Q4,
        mistralSmall3_24B_Q4
    ]

    public static let allVision: [ModelDescriptor] = [
        gemma4_e2b_Q4,
        gemma4_e4b_Q4
    ]

    public static let all: [ModelDescriptor] = allText + allVision

    /// Chat template hint aligned with model family.
    public static func chatTemplate(for descriptor: ModelDescriptor) -> ChatTemplate {
        ChatTemplate.auto(name: descriptor.name)
    }
}
