// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SentimentClassifierKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "SentimentClassifierKit",
            targets: ["SentimentClassifierKit"]
        )
    ],
    targets: [
        .target(
            name: "SentimentClassifierKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SentimentClassifierKitTests",
            dependencies: ["SentimentClassifierKit"]
        )
    ]
)

