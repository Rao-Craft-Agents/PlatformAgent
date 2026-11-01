// swift-tools-version:6.0
// PlatformAgent: the platform layer of an iOS + macOS Xcode project (the app delegate, entitlements, Info keys and URL
// schemes, macOS menu commands, app extensions), done by editing the project, as a Granite agent package.
// An app that links it finds the `platform` agent through Granite's roster, with nothing listed by hand.

import PackageDescription

let package = Package(
    name: "PlatformAgent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PlatformAgent", targets: ["PlatformAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "PlatformAgent",
            dependencies: [.product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "PlatformAgentTests",
            dependencies: ["PlatformAgent", .product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
