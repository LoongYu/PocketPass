// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pockit",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "pockit", targets: ["pockit"])],
    targets: [
        .executableTarget(
            name: "pockit",
            path: "Sources/pockit",
            resources: [.process("Resources")]
        )
    ]
)
