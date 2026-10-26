// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ChairKit",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v15),
    ],
    products: [
        .library(name: "ChairKit", targets: ["ChairKit"]),
    ],
    targets: [
        .target(name: "ChairKit"),
        .testTarget(
            name: "ChairKitTests",
            dependencies: ["ChairKit"]
        ),
    ]
)
