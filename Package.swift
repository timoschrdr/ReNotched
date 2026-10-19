// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ReNotched",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(name: "ReNotched", path: "Sources/ReNotched")
    ]
)
