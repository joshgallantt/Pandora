// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Pandoras",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Pandoras",
            targets: ["Pandoras"]
        ),
    ],
    targets: [
        .target(
            name: "Pandoras"
        ),
        .testTarget(
            name: "PandorasTests",
            dependencies: ["Pandoras"]
        ),
    ]
)
