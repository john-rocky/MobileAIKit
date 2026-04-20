import Foundation

/// Curated list of on-device-friendly local models with URLs that `ModelDownloader` can fetch.
///
/// The catalog prioritises recent (2025–2026) small-to-mid models that fit within
/// an iPhone's RAM budget. All GGUF entries are Q4_K_M quantisations; MLX entries
/// point at `mlx-community` 4-bit packs. Bring your own `ModelDescriptor` for
/// anything not listed.
public enum ModelCatalog {

    // MARK: GGUF (llama.cpp)

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

    /// Gemma 3 4B Instruct (Mar 2025). Multimodal-capable weights (text here; use MLX VLM for vision).
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

    // MARK: MLX 4-bit (mlx-swift-examples)

    public static let mlx_qwen3_0_6B = ModelDescriptor(
        name: "mlx-qwen3-0.6b", version: "4bit",
        format: .mlx, contextLength: 32_768, files: [],
        displayName: "MLX Qwen 3 0.6B 4bit", minRAMBytes: 1_000_000_000
    )

    public static let mlx_qwen3_1_7B = ModelDescriptor(
        name: "mlx-qwen3-1.7b", version: "4bit",
        format: .mlx, contextLength: 32_768, files: [],
        displayName: "MLX Qwen 3 1.7B 4bit", minRAMBytes: 2_500_000_000
    )

    public static let mlx_qwen3_4B = ModelDescriptor(
        name: "mlx-qwen3-4b", version: "4bit",
        format: .mlx, contextLength: 32_768, files: [],
        displayName: "MLX Qwen 3 4B 4bit", minRAMBytes: 5_000_000_000
    )

    public static let mlx_qwen3_8B = ModelDescriptor(
        name: "mlx-qwen3-8b", version: "4bit",
        format: .mlx, contextLength: 32_768, files: [],
        displayName: "MLX Qwen 3 8B 4bit", minRAMBytes: 9_000_000_000
    )

    public static let mlx_gemma3_1B = ModelDescriptor(
        name: "mlx-gemma-3-1b-it", version: "4bit",
        format: .mlx, contextLength: 32_768, files: [],
        displayName: "MLX Gemma 3 1B 4bit", minRAMBytes: 2_000_000_000
    )

    public static let mlx_gemma3_4B = ModelDescriptor(
        name: "mlx-gemma-3-4b-it", version: "4bit",
        format: .mlx, modality: .vision, contextLength: 131_072, files: [],
        displayName: "MLX Gemma 3 4B IT 4bit (multimodal)", minRAMBytes: 5_000_000_000
    )

    public static let mlx_gemma4_e2b = ModelDescriptor(
        name: "mlx-gemma-4-e2b-it", version: "4bit",
        format: .mlx, modality: .vision, contextLength: 131_072, files: [],
        displayName: "MLX Gemma 4 E2B IT 4bit (multimodal)", minRAMBytes: 2_500_000_000
    )

    public static let mlx_gemma4_e4b = ModelDescriptor(
        name: "mlx-gemma-4-e4b-it", version: "4bit",
        format: .mlx, modality: .vision, contextLength: 131_072, files: [],
        displayName: "MLX Gemma 4 E4B IT 4bit (multimodal)", minRAMBytes: 5_000_000_000
    )

    public static let mlx_gemma4_26b_moe = ModelDescriptor(
        name: "mlx-gemma-4-26b-moe-it", version: "4bit",
        format: .mlx, contextLength: 131_072, files: [],
        displayName: "MLX Gemma 4 26B MoE IT 4bit", minRAMBytes: 20_000_000_000
    )

    public static let mlx_gemma4_31b_dense = ModelDescriptor(
        name: "mlx-gemma-4-31b-it", version: "4bit",
        format: .mlx, contextLength: 131_072, files: [],
        displayName: "MLX Gemma 4 31B Dense IT 4bit", minRAMBytes: 24_000_000_000
    )

    public static let mlx_phi4_mini = ModelDescriptor(
        name: "mlx-phi-4-mini-instruct", version: "4bit",
        format: .mlx, contextLength: 131_072, files: [],
        displayName: "MLX Phi-4 mini 4bit", minRAMBytes: 4_500_000_000
    )

    public static let mlx_smollm3_3B = ModelDescriptor(
        name: "mlx-smollm3-3b", version: "4bit",
        format: .mlx, contextLength: 65_536, files: [],
        displayName: "MLX SmolLM3 3B 4bit", minRAMBytes: 4_000_000_000
    )

    /// Legacy — Llama 3.2 1B MLX for broad device support.
    public static let mlx_llama3_2_1B = ModelDescriptor(
        name: "mlx-llama-3.2-1b-instruct", version: "4bit",
        format: .mlx, contextLength: 131_072, files: [],
        displayName: "MLX Llama 3.2 1B (legacy)", minRAMBytes: 2_000_000_000
    )

    // MARK: MLX Vision (VLM)

    public static let mlx_qwen25_vl_3B = ModelDescriptor(
        name: "mlx-qwen2.5-vl-3b-instruct", version: "4bit",
        format: .mlx, modality: .vision, contextLength: 32_768, files: [],
        displayName: "MLX Qwen 2.5 VL 3B 4bit", minRAMBytes: 4_500_000_000
    )

    public static let mlx_qwen25_vl_7B = ModelDescriptor(
        name: "mlx-qwen2.5-vl-7b-instruct", version: "4bit",
        format: .mlx, modality: .vision, contextLength: 32_768, files: [],
        displayName: "MLX Qwen 2.5 VL 7B 4bit", minRAMBytes: 8_000_000_000
    )

    public static let mlx_phi4_multimodal = ModelDescriptor(
        name: "mlx-phi-4-multimodal-instruct", version: "4bit",
        format: .mlx, modality: .vision, contextLength: 131_072, files: [],
        displayName: "MLX Phi-4 Multimodal 4bit", minRAMBytes: 7_000_000_000
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
        mistralSmall3_24B_Q4,
        mlx_gemma4_e2b,
        mlx_gemma4_e4b,
        mlx_gemma4_26b_moe,
        mlx_gemma4_31b_dense,
        mlx_qwen3_0_6B,
        mlx_qwen3_1_7B,
        mlx_qwen3_4B,
        mlx_qwen3_8B,
        mlx_gemma3_1B,
        mlx_gemma3_4B,
        mlx_phi4_mini,
        mlx_smollm3_3B,
        mlx_llama3_2_1B
    ]

    public static let allVision: [ModelDescriptor] = [
        gemma4_e2b_Q4,
        gemma4_e4b_Q4,
        mlx_gemma4_e2b,
        mlx_gemma4_e4b,
        mlx_qwen25_vl_3B,
        mlx_qwen25_vl_7B,
        mlx_phi4_multimodal,
        mlx_gemma3_4B
    ]

    public static let all: [ModelDescriptor] = allText + allVision

    /// Maps an MLX descriptor to the `mlx-community` repo id used by ``MLXBackend``.
    public static func mlxHubId(for descriptor: ModelDescriptor) -> String? {
        switch descriptor.name {
        case "mlx-gemma-4-e2b-it":           return "mlx-community/gemma-4-e2b-it-4bit"
        case "mlx-gemma-4-e4b-it":           return "mlx-community/gemma-4-e4b-it-4bit"
        case "mlx-gemma-4-26b-moe-it":       return "mlx-community/gemma-4-26b-moe-it-4bit"
        case "mlx-gemma-4-31b-it":           return "mlx-community/gemma-4-31b-it-4bit"
        case "mlx-qwen3-0.6b":               return "mlx-community/Qwen3-0.6B-4bit"
        case "mlx-qwen3-1.7b":               return "mlx-community/Qwen3-1.7B-4bit"
        case "mlx-qwen3-4b":                 return "mlx-community/Qwen3-4B-4bit"
        case "mlx-qwen3-8b":                 return "mlx-community/Qwen3-8B-4bit"
        case "mlx-gemma-3-1b-it":            return "mlx-community/gemma-3-1b-it-4bit"
        case "mlx-gemma-3-4b-it":            return "mlx-community/gemma-3-4b-it-4bit"
        case "mlx-phi-4-mini-instruct":      return "mlx-community/Phi-4-mini-instruct-4bit"
        case "mlx-smollm3-3b":               return "mlx-community/SmolLM3-3B-4bit"
        case "mlx-llama-3.2-1b-instruct":    return "mlx-community/Llama-3.2-1B-Instruct-4bit"
        case "mlx-qwen2.5-vl-3b-instruct":   return "mlx-community/Qwen2.5-VL-3B-Instruct-4bit"
        case "mlx-qwen2.5-vl-7b-instruct":   return "mlx-community/Qwen2.5-VL-7B-Instruct-4bit"
        case "mlx-phi-4-multimodal-instruct": return "mlx-community/Phi-4-multimodal-instruct-4bit"
        default: return nil
        }
    }

    /// Chat template hint aligned with model family. Pass to `LlamaCppBackend(template:)`.
    public static func chatTemplate(for descriptor: ModelDescriptor) -> ChatTemplate {
        ChatTemplate.auto(name: descriptor.name)
    }
}
