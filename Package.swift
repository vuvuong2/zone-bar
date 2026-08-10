// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ZoneBar",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: models, services, menu construction. No AppKit event loop.
        .target(
            name: "ZoneBarCore",
            path: "Sources/ZoneBarCore"
        ),
        // Thin app shell: NSApplication, status item, settings window.
        .executableTarget(
            name: "ZoneBar",
            dependencies: ["ZoneBarCore"],
            path: "Sources/ZoneBar"
        ),
        // XCTest ships inside Xcode, not the Command Line Tools, so the suite is
        // a plain executable instead of a test target. Run: swift run ZoneBarTests
        .executableTarget(
            name: "ZoneBarTests",
            dependencies: ["ZoneBarCore"],
            path: "Tests/ZoneBarTests"
        ),
    ]
)
