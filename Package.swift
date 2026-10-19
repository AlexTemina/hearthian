// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Hearthian",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Hearthian", path: "Sources/Hearthian")
    ]
)
