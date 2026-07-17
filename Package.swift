// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FinishInbox",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FinishInboxCore", targets: ["FinishInboxCore"]),
        .executable(name: "finish-inbox", targets: ["FinishInbox"]),
    ],
    targets: [
        .target(
            name: "FinishInboxCore",
            path: "Sources/FinishInboxCore"
        ),
        .executableTarget(
            name: "FinishInbox",
            dependencies: ["FinishInboxCore"],
            path: "Sources/FinishInbox"
        ),
        .testTarget(
            name: "FinishInboxCoreTests",
            dependencies: ["FinishInboxCore"],
            path: "Tests/FinishInboxCoreTests"
        ),
    ]
)
