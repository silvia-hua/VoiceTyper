// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VoiceTyper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VoiceTyper", targets: ["VoiceTyper"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceTyper",
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
