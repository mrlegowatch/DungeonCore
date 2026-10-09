// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DungeonCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "DungeonCore",
            targets: ["DungeonCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/mrlegowatch/RolePlayingCore.git", from: "0.1.0"),
        .package(url: "https://github.com/mrlegowatch/SwiftDice.git", from: "0.1.0"),
    ],   targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DungeonCore",
            dependencies: [
                .product(name: "RolePlayingCore", package: "RolePlayingCore"),
            ],
        ),
        .testTarget(
            name: "DungeonCoreTests",
            dependencies: [
                "DungeonCore",
                .product(name: "RolePlayingCore", package: "RolePlayingCore"),
            ],
            resources: [
                .process("TestResources"),
            ],
        ),
    ]
)
