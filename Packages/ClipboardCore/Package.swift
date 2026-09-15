// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipboardCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ClipboardCore", targets: ["ClipboardCore"])
    ],
    targets: [
        .target(name: "ClipboardCore")
        // Test target omitted: this environment has Command Line Tools
        // only, no Xcode.app, so XCTest/Testing don't resolve. Real
        // verification happens in DevTools/ClipboardCoreTests instead —
        // see that package and DevTools/README.md.
    ]
)
