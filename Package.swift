// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Parte",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Parte", path: "Sources/Parte")
    ]
)
