// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusFlow",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "FocusFlow",
            path: "Sources/FocusFlow",
            exclude: [
                "FocusFlow.entitlements",
                "Resources/Info.plist"
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("EventKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "FocusFlowTests",
            dependencies: ["FocusFlow"],
            path: "Tests"
        )
    ]
)
