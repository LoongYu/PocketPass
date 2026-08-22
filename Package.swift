// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PocketPass",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "PocketPassCore", targets: ["PocketPassCore"]),
        .executable(name: "PocketPass", targets: ["PocketPass"])
    ],
    targets: [
        .target(
            name: "PocketPassCore",
            path: "Sources/PocketPassCore"
        ),
        .executableTarget(
            name: "PocketPass",
            dependencies: ["PocketPassCore"],
            path: "Sources/PocketPass",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PocketPassCoreTests",
            dependencies: ["PocketPassCore"],
            path: "Tests/PocketPassCoreTests"
        )
    ]
)
