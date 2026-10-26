// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ChairUI",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "ChairUI", targets: ["ChairUI"]),
    ],
    dependencies: [
        .package(path: "../ChairKit"),
    ],
    targets: [
        .target(
            name: "ChairUI",
            dependencies: ["ChairKit"]
        ),
        .testTarget(
            name: "ChairUIPackageTests",
            dependencies: ["ChairUI"]
        ),
    ]
)
