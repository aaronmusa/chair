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
        .library(name: "ChairTestSupport", targets: ["ChairTestSupport"]),
    ],
    targets: [
        .target(name: "ChairKit"),
        .target(
            name: "ChairTestSupport",
            dependencies: ["ChairKit"]
        ),
        .testTarget(
            name: "ChairKitTests",
            dependencies: ["ChairKit", "ChairTestSupport"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
