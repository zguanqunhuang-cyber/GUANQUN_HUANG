// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlayAppFeature",
    platforms: [.iOS(.v18)],
    products: [
        .library(
            name: "PlayAppFeature",
            targets: ["PlayAppFeature"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "2.9.0")
    ],
    targets: [
        .target(
            name: "PlayAppFeature",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]
        ),
        .testTarget(
            name: "PlayAppFeatureTests",
            dependencies: [
                "PlayAppFeature"
            ]
        ),
    ]
)
