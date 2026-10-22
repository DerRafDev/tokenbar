// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TokenBarKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TokenBarCore", targets: ["TokenBarCore"]),
        .library(name: "TokenBarUI", targets: ["TokenBarUI"]),
    ],
    targets: [
        // Domain model, provider protocol, refresh policy. No UI, no networking.
        .target(name: "TokenBarCore"),
        // SwiftUI views. Must never depend on TokenBarProviders.
        .target(name: "TokenBarUI", dependencies: ["TokenBarCore"]),

        .testTarget(name: "TokenBarCoreTests", dependencies: ["TokenBarCore"]),
        .testTarget(name: "TokenBarUITests", dependencies: ["TokenBarUI", "TokenBarCore"]),
    ]
)
