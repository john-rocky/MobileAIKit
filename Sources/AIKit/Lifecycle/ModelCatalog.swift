import Foundation

public enum ModelCatalog {
    public static let llama3_2_1B_Instruct_Q4 = ModelDescriptor(
        name: "llama-3.2-1b-instruct",
        version: "q4_k_m",
        format: .gguf,
        modality: .text,
        contextLength: 131072,
        files: [
            ModelFile(
                relativePath: "Llama-3.2-1B-Instruct-Q4_K_M.gguf",
                url: URL(string: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf")!
            )
        ],
        displayName: "Llama 3.2 1B Instruct (Q4_K_M)",
        minRAMBytes: 2_000_000_000
    )

    public static let llama3_2_3B_Instruct_Q4 = ModelDescriptor(
        name: "llama-3.2-3b-instruct",
        version: "q4_k_m",
        format: .gguf,
        modality: .text,
        contextLength: 131072,
        files: [
            ModelFile(
                relativePath: "Llama-3.2-3B-Instruct-Q4_K_M.gguf",
                url: URL(string: "https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf")!
            )
        ],
        displayName: "Llama 3.2 3B Instruct (Q4_K_M)",
        minRAMBytes: 4_000_000_000
    )

    public static let qwen2_5_0_5B_Q4 = ModelDescriptor(
        name: "qwen2.5-0.5b-instruct",
        version: "q4_k_m",
        format: .gguf,
        modality: .text,
        contextLength: 32768,
        files: [
            ModelFile(
                relativePath: "qwen2.5-0.5b-instruct-q4_k_m.gguf",
                url: URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf")!
            )
        ],
        displayName: "Qwen2.5 0.5B (Q4_K_M)",
        minRAMBytes: 1_000_000_000
    )

    public static let gemma2_2B_Q4 = ModelDescriptor(
        name: "gemma-2-2b-it",
        version: "q4_k_m",
        format: .gguf,
        modality: .text,
        contextLength: 8192,
        files: [
            ModelFile(
                relativePath: "gemma-2-2b-it-Q4_K_M.gguf",
                url: URL(string: "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf")!
            )
        ],
        displayName: "Gemma 2 2B Instruct (Q4_K_M)",
        minRAMBytes: 3_000_000_000
    )

    public static let mlx_llama_3_2_1B = ModelDescriptor(
        name: "mlx-llama-3.2-1b-instruct",
        version: "4bit",
        format: .mlx,
        modality: .text,
        contextLength: 131072,
        files: [],
        displayName: "MLX Llama 3.2 1B Instruct 4bit",
        minRAMBytes: 2_000_000_000
    )

    public static let mlx_qwen_2_5_0_5B = ModelDescriptor(
        name: "mlx-qwen-2.5-0.5b-instruct",
        version: "4bit",
        format: .mlx,
        modality: .text,
        contextLength: 32768,
        files: [],
        displayName: "MLX Qwen 2.5 0.5B Instruct 4bit",
        minRAMBytes: 1_000_000_000
    )

    public static let allText: [ModelDescriptor] = [
        llama3_2_1B_Instruct_Q4,
        llama3_2_3B_Instruct_Q4,
        qwen2_5_0_5B_Q4,
        gemma2_2B_Q4,
        mlx_llama_3_2_1B,
        mlx_qwen_2_5_0_5B
    ]

    public static func mlxHubId(for descriptor: ModelDescriptor) -> String? {
        switch descriptor.name {
        case "mlx-llama-3.2-1b-instruct": return "mlx-community/Llama-3.2-1B-Instruct-4bit"
        case "mlx-qwen-2.5-0.5b-instruct": return "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
        default: return nil
        }
    }
}
