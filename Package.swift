// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Pandora",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Pandora",
            targets: ["Pandora"]
        ),
    ],
    targets: [
        .target(
            name: "Pandora"
        ),
        .testTarget(
            name: "PandoraTests",
            dependencies: ["Pandora"]
        ),
    ]
)
