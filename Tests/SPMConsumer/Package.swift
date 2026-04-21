// swift-tools-version: 6.0
//
// Downstream-consumer fixture. CI runs
//   `xcodebuild -resolvePackageDependencies -packagePath Tests/SPMConsumer`
// against this manifest, which performs the graph-level product and
// version-constraint validation that plain `swift package resolve` on the
// root skips. Round 5 (Tokenizers product missing) and Round 6
// (swift-transformers 1.1.x vs mlx-swift-examples cap) both slipped
// through `swift package resolve` but fail this check immediately.
//
// Every library product exported by the root Package.swift must have a
// matching target-dependency entry below, otherwise a broken product
// reference can regress unnoticed.
import PackageDescription

let package = Package(
    name: "SPMConsumer",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2),
        .tvOS(.v18),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "SPMConsumer", targets: ["SPMConsumer"])
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .target(
            name: "SPMConsumer",
            dependencies: [
                .product(name: "AIKit", package: "LocalAIKit"),
                .product(name: "AIKitFoundationModels", package: "LocalAIKit"),
                .product(name: "AIKitMLX", package: "LocalAIKit"),
                .product(name: "AIKitLlamaCpp", package: "LocalAIKit"),
                .product(name: "AIKitCoreML", package: "LocalAIKit"),
                .product(name: "AIKitCoreMLLLM", package: "LocalAIKit"),
                .product(name: "AIKitVision", package: "LocalAIKit"),
                .product(name: "AIKitSpeech", package: "LocalAIKit"),
                .product(name: "AIKitWhisperKit", package: "LocalAIKit"),
                .product(name: "AIKitUI", package: "LocalAIKit"),
                .product(name: "AIKitIntegration", package: "LocalAIKit"),
                .product(name: "AIKitAgent", package: "LocalAIKit")
            ]
        )
    ]
)
