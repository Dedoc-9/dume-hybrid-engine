// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "DUMEHybridEngine",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "DUMEHybridEngine", targets: ["DUMEHybridEngine"])
    ],
    dependencies: [
        // Add any required dependencies here
    ],
    targets: [
        .target(name: "DUMEHybridEngine", dependencies: []),
        .testTarget(name: "DUMEHybridEngineTests", dependencies: ["DUMEHybridEngine"])
    ]
)