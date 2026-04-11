// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PankeyCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PankeyCore", targets: ["PankeyCore"])
    ],
    targets: [
        .target(
            name: "PankeyCore",
            path: "Sources/PankeyCore"
        ),
        .testTarget(
            name: "PankeyCoreTests",
            dependencies: ["PankeyCore"],
            path: "Tests/PankeyCoreTests"
        )
    ]
)
