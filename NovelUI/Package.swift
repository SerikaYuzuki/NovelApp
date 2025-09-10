// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NovelUI",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NovelUI",
            targets: ["NovelUI"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "NovelCore", path: "../NovelCore"),
        .package(name: "NovelStorage", path: "../NovelStorage"),
        .package(name: "EditorKit", path: "../EditorKit"),
        
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NovelUI",
            dependencies: [
                .product(name: "NovelCore", package: "NovelCore"),
                .product(name: "NovelStorage", package: "NovelStorage"),
                .product(name: "EditorKit", package: "EditorKit")
            ]
        ),
        .testTarget(
            name: "NovelUITests",
            dependencies: ["NovelUI"]
        ),
    ]
)
