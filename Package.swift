// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SysBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SysBar",
            path: "Sources",
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit", "-framework", "IOKit", "-framework", "CoreFoundation"])
            ]
        )
    ]
)
