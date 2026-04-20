// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MobileAIKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "AIKit", targets: ["AIKit"]),
        .library(name: "AIKitFoundationModels", targets: ["AIKitFoundationModels"]),
        .library(name: "AIKitMLX", targets: ["AIKitMLX"]),
        .library(name: "AIKitLlamaCpp", targets: ["AIKitLlamaCpp"]),
        .library(name: "AIKitCoreML", targets: ["AIKitCoreML"]),
        .library(name: "AIKitVision", targets: ["AIKitVision"]),
        .library(name: "AIKitSpeech", targets: ["AIKitSpeech"]),
        .library(name: "AIKitUI", targets: ["AIKitUI"]),
        .library(name: "AIKitIntegration", targets: ["AIKitIntegration"]),
        .library(name: "AIKitAll", targets: [
            "AIKit",
            "AIKitFoundationModels",
            "AIKitMLX",
            "AIKitLlamaCpp",
            "AIKitCoreML",
            "AIKitVision",
            "AIKitSpeech",
            "AIKitUI",
            "AIKitIntegration"
        ])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.2"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "2.21.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.17"),
        .package(url: "https://github.com/ggml-org/llama.cpp", branch: "master")
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
        .testTarget(
            name: "AIKitTests",
            dependencies: ["AIKit"],
            path: "Tests/AIKitTests"
        )
    ]
)
