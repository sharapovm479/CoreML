// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ImageClassifierKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "ImageClassifierKit",
            targets: ["ImageClassifierKit"]
        )
    ],
    targets: [
        .target(
            name: "ImageClassifierKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ImageClassifierKitTests",
            dependencies: ["ImageClassifierKit"]
        )
    ]
)

