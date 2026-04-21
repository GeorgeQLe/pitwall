// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Pitwall",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PitwallCore",
            targets: ["PitwallCore"]
        )
    ],
    targets: [
        .target(
            name: "PitwallCore"
        ),
        .testTarget(
            name: "PitwallCoreTests",
            dependencies: ["PitwallCore"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
