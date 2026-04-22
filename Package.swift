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
        .library(name: "AIKitCoreMLLLM", targets: ["AIKitCoreMLLLM"]),
        .library(name: "AIKitVision", targets: ["AIKitVision"]),
        .library(name: "AIKitSpeech", targets: ["AIKitSpeech"]),
        .library(name: "AIKitUI", targets: ["AIKitUI"]),
        .library(name: "AIKitIntegration", targets: ["AIKitIntegration"]),
        .library(name: "AIKitAgent", targets: ["AIKitAgent"]),
        .library(name: "AIKitAll", targets: [
            "AIKit",
            "AIKitCoreMLLLM",
            "AIKitVision",
            "AIKitSpeech",
            "AIKitUI",
            "AIKitIntegration",
            "AIKitAgent"
        ])
    ],
    dependencies: [
        .package(url: "https://github.com/john-rocky/coreml-llm", from: "1.1.1")
    ],
    targets: [
        .target(
            name: "AIKit",
            dependencies: [],
            path: "Sources/AIKit"
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
