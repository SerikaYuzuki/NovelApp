// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EditorKit",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "EditorKit",
            targets: ["EditorKit"]
        ),
    ],
    dependencies: [
        .package(name: "NovelCore", path: "../NovelCore"),
        .package(name: "NovelStorage", path: "../NovelStorage"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "EditorKit",
            dependencies: [
                .product(name: "NovelCore", package: "NovelCore"),
                .product(name: "NovelStorage", package: "NovelStorage")
            ]
        ),
        .testTarget(
            name: "EditorKitTests",
            dependencies: ["EditorKit"]
        ),
    ]
)
