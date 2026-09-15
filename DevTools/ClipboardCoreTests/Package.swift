// swift-tools-version: 6.0
import PackageDescription

// ClipboardCore-level pass/fail harness — see DevTools/README.md. No
// XCTest/Swift Testing available (Command Line Tools only, no Xcode).
// Writes to the REAL NSPasteboard.general (there's no sandboxed
// alternative) — always restores whatever was on it before the run, same
// discipline as MacSecureSSH's tests never touching real user data.
let package = Package(
    name: "ClipboardCoreTests",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/ClipboardCore")
    ],
    targets: [
        .executableTarget(name: "ClipboardCoreTests", dependencies: ["ClipboardCore"])
    ]
)
