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
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.19.6"),
    ],
    targets: [
        .target(
            name: "ChairUI",
            dependencies: ["ChairKit"],
            resources: [.process("Tokens/Colors.xcassets")]
        ),
        .testTarget(
            name: "ChairUIPackageTests",
            dependencies: [
                "ChairUI",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["__Snapshots__"]
        ),
    ]
)
