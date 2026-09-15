// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacClip",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MacClipCore", targets: ["MacClipCore"])
    ],
    dependencies: [
        .package(path: "../Packages/ClipboardCore")
    ],
    targets: [
        // App logic (AppModel, HotKeyManager) separated from the thin
        // executable so it can be exercised by a standalone test harness —
        // this environment has no Xcode/XCTest, so a real SPM executable
        // that imports this and asserts on it is how correctness actually
        // gets verified here, not just re-reading the code.
        .target(
            name: "MacClipCore",
            dependencies: ["ClipboardCore"]
        ),
        .executableTarget(
            name: "MacClip",
            dependencies: ["ClipboardCore", "MacClipCore"]
        )
    ]
)
