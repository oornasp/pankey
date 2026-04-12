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
            path: "Tests/PankeyCoreTests",
            swiftSettings: [
                // Swift Testing framework path (CommandLineTools, no Xcode required)
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
