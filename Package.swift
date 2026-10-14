// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlmUsageBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "GlmUsageBar", path: "Sources/GlmUsageBar")
    ]
)
