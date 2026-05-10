// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "IqamahCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "IqamahCore", targets: ["IqamahCore"]),
    ],
    targets: [
        .target(
            name: "IqamahCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "IqamahCoreTests",
            dependencies: ["IqamahCore"]
        ),
    ]
)
