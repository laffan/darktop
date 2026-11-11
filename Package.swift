// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Darktop",
    platforms: [.macOS(.v11)],
    targets: [
        // Pure table math, kept free of AppKit/CoreGraphics so it can be unit tested.
        .target(name: "DarktopCore"),
        .executableTarget(name: "Darktop", dependencies: ["DarktopCore"]),
        .testTarget(name: "DarktopCoreTests", dependencies: ["DarktopCore"]),
    ]
)
