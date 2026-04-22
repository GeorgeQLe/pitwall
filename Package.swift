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
        ),
        .library(
            name: "PitwallShared",
            targets: ["PitwallShared"]
        ),
        .library(
            name: "PitwallAppSupport",
            targets: ["PitwallAppSupport"]
        ),
        .executable(
            name: "PitwallApp",
            targets: ["PitwallApp"]
        )
    ],
    targets: [
        .target(
            name: "PitwallCore",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .target(
            name: "PitwallShared",
            dependencies: ["PitwallCore"]
        ),
        .target(
            name: "PitwallAppSupport",
            dependencies: ["PitwallCore", "PitwallShared"]
        ),
        .executableTarget(
            name: "PitwallApp",
            dependencies: ["PitwallAppSupport"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "PitwallCoreTests",
            dependencies: ["PitwallCore"],
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "PitwallAppSupportTests",
            dependencies: [
                "PitwallAppSupport",
                "PitwallCore"
            ]
        ),
        .testTarget(
            name: "PitwallSharedTests",
            dependencies: [
                "PitwallShared",
                "PitwallCore"
            ]
        )
    ]
)
