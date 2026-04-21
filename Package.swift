// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalAIKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2),
        .tvOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "AIKit", targets: ["AIKit"]),
        .library(name: "AIKitFoundationModels", targets: ["AIKitFoundationModels"]),
        .library(name: "AIKitMLX", targets: ["AIKitMLX"]),
        .library(name: "AIKitLlamaCpp", targets: ["AIKitLlamaCpp"]),
        .library(name: "AIKitCoreML", targets: ["AIKitCoreML"]),
        .library(name: "AIKitCoreMLLLM", targets: ["AIKitCoreMLLLM"]),
        .library(name: "AIKitVision", targets: ["AIKitVision"]),
        .library(name: "AIKitSpeech", targets: ["AIKitSpeech"]),
        .library(name: "AIKitUI", targets: ["AIKitUI"]),
        .library(name: "AIKitIntegration", targets: ["AIKitIntegration"]),
        .library(name: "AIKitAgent", targets: ["AIKitAgent"]),
        .library(name: "AIKitAll", targets: [
            "AIKit",
            "AIKitFoundationModels",
            "AIKitMLX",
            "AIKitLlamaCpp",
            "AIKitCoreML",
            "AIKitCoreMLLLM",
            "AIKitVision",
            "AIKitSpeech",
            "AIKitUI",
            "AIKitIntegration",
            "AIKitAgent"
        ])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.2"),
        // Pinned to 2.29.1: every published version of mlx-swift-examples caps
        // swift-transformers at `<1.1.0`. 2.29.x is the line that accepts 1.0.x.
        // Until mlx-swift-examples bumps its own swift-transformers floor, this
        // range must stay narrow — any version that only accepts 0.1.x will
        // deadlock against AIKitCoreML's `Hub` / `Tokenizers` product refs.
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", "2.29.1"..<"2.29.2"),
        // Pinned to 1.0.x: mlx-swift-examples caps at `<1.1.0` (see above) and
        // the 1.0.x line already exposes `Hub` / `Tokenizers` as independent
        // library products, so AIKitCoreML's `.product(name: "Tokenizers"…)`
        // target deps resolve. Revisit when mlx-swift-examples supports 1.1.x.
        .package(url: "https://github.com/huggingface/swift-transformers", "1.0.0"..<"1.1.0"),
        // Pinned: llama.cpp removed Package.swift from master on 2025-03-05 (PR #11996).
        // 5bbe6a9f is the last commit that shipped a root Package.swift exporting the `llama` product.
        .package(url: "https://github.com/ggml-org/llama.cpp", revision: "5bbe6a9fe9a8796a9389c85accec89dbc4d91e39"),
        .package(url: "https://github.com/john-rocky/coreml-llm", from: "0.9.0")
        // WhisperKit intentionally not declared here. No published version is
        // compatible with both mlx-swift-examples (caps swift-transformers at
        // <1.1.0) and WhisperKit 0.15+ (requires 1.1.x); WhisperKit 0.14.x
        // requires 0.1.x, which breaks AIKitCoreML's Hub / Tokenizers product
        // references. Users who need Whisper can add WhisperKit to their own
        // package and conform to `VoiceTranscriber` (see README).
    ],
    targets: [
        .target(
            name: "AIKit",
            dependencies: [],
            path: "Sources/AIKit"
        ),
        .target(
            name: "AIKitFoundationModels",
            dependencies: ["AIKit"],
            path: "Sources/AIKitFoundationModels"
        ),
        .target(
            name: "AIKitMLX",
            dependencies: [
                "AIKit",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXVLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples")
            ],
            path: "Sources/AIKitMLX"
        ),
        .target(
            name: "AIKitLlamaCpp",
            dependencies: [
                "AIKit",
                .product(name: "llama", package: "llama.cpp")
            ],
            path: "Sources/AIKitLlamaCpp"
        ),
        .target(
            name: "AIKitCoreML",
            dependencies: [
                "AIKit",
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "Hub", package: "swift-transformers")
            ],
            path: "Sources/AIKitCoreML"
        ),
        .target(
            name: "AIKitCoreMLLLM",
            dependencies: [
                "AIKit",
                .product(name: "CoreMLLLM", package: "coreml-llm")
            ],
            path: "Sources/AIKitCoreMLLLM"
        ),
        .target(
            name: "AIKitVision",
            dependencies: ["AIKit"],
            path: "Sources/AIKitVision"
        ),
        .target(
            name: "AIKitSpeech",
            dependencies: ["AIKit"],
            path: "Sources/AIKitSpeech"
        ),
        .target(
            name: "AIKitUI",
            dependencies: ["AIKit"],
            path: "Sources/AIKitUI"
        ),
        .target(
            name: "AIKitIntegration",
            dependencies: ["AIKit"],
            path: "Sources/AIKitIntegration"
        ),
        .target(
            name: "AIKitAgent",
            dependencies: [
                "AIKit",
                "AIKitUI",
                "AIKitIntegration",
                "AIKitVision",
                "AIKitSpeech"
            ],
            path: "Sources/AIKitAgent"
        ),
        .testTarget(
            name: "AIKitTests",
            dependencies: ["AIKit"],
            path: "Tests/AIKitTests"
        )
    ]
)
