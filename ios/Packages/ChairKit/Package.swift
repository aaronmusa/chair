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
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", exact: "2.55.4"),
    ],
    targets: [
        .target(
            name: "ChairKit",
            dependencies: [.product(name: "Supabase", package: "supabase-swift")]
        ),
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
