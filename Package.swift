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
        .library(name: "AIKitWhisperKit", targets: ["AIKitWhisperKit"]),
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
            "AIKitWhisperKit",
            "AIKitUI",
            "AIKitIntegration",
            "AIKitAgent"
        ])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.2"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "2.21.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.17"),
        // Pinned: llama.cpp removed Package.swift from master on 2025-03-05 (PR #11996).
        // 5bbe6a9f is the last commit that shipped a root Package.swift exporting the `llama` product.
        .package(url: "https://github.com/ggml-org/llama.cpp", revision: "5bbe6a9fe9a8796a9389c85accec89dbc4d91e39"),
        .package(url: "https://github.com/john-rocky/coreml-llm", branch: "main"),
        // Pinned to 0.14.x: WhisperKit >= 0.15 requires swift-transformers 1.1.x,
        // which conflicts with coreml-llm (needs 0.1.x). Revisit once coreml-llm
        // moves to swift-transformers 1.x.
        .package(url: "https://github.com/argmaxinc/WhisperKit", "0.14.1"..<"0.15.0")
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
            name: "AIKitWhisperKit",
            dependencies: [
                "AIKit",
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/AIKitWhisperKit"
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
