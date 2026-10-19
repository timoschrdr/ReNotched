// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ReNotched",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ReNotched", path: "Sources/ReNotched")
    ]
)
