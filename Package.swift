// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PocketPass",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "PocketPass", targets: ["PocketPass"])],
    targets: [
        .executableTarget(
            name: "PocketPass",
            path: "Sources/PocketPass",
            resources: [.process("Resources")]
        )
    ]
)
