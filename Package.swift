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
        .library(
            name: "PitwallWindows",
            targets: ["PitwallWindows"]
        ),
        .library(
            name: "PitwallLinux",
            targets: ["PitwallLinux"]
        ),
        .executable(
            name: "PitwallApp",
            targets: ["PitwallApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
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
        .target(
            name: "PitwallWindows",
            dependencies: ["PitwallCore", "PitwallShared"]
        ),
        .target(
            name: "PitwallLinux",
            dependencies: ["PitwallCore", "PitwallShared"]
        ),
        .executableTarget(
            name: "PitwallApp",
            dependencies: [
                "PitwallAppSupport",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            exclude: ["Info.plist", "Pitwall.entitlements"],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement")
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
        ),
        .testTarget(
            name: "PitwallWindowsTests",
            dependencies: [
                "PitwallWindows",
                "PitwallShared",
                "PitwallCore"
            ]
        ),
        .testTarget(
            name: "PitwallLinuxTests",
            dependencies: [
                "PitwallLinux",
                "PitwallShared",
                "PitwallCore"
            ]
        )
    ]
)
