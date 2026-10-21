// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DynamicNotch",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DynamicNotch", targets: ["DynamicNotch"]),
        // Loaded by /usr/bin/perl at runtime, never linked into the app.
        .library(name: "NotchMediaBridge", type: .dynamic, targets: ["NotchMediaBridge"]),
    ],
    targets: [
        .target(
            name: "NotchMediaBridge",
            path: "Sources/NotchMediaBridge",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .target(
            name: "NotchKit",
            path: "Sources/NotchKit"
        ),
        .executableTarget(
            name: "DynamicNotch",
            dependencies: ["NotchKit"],
            path: "Sources/DynamicNotch"
        ),
        .testTarget(
            name: "NotchKitTests",
            dependencies: ["NotchKit"],
            path: "Tests/NotchKitTests"
        ),
    ]
)
