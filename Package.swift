// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeridianCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "MeridianCore",
            targets: ["MeridianCore"]
        ),
        .library(
            name: "Resilience",
            targets: ["Resilience"]
        ),
        // Compatibility alias for transition
        .library(
            name: "DataStructures",
            targets: ["MeridianCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MeridianCore",
            dependencies: [],
            path: "Sources/MeridianCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "Resilience",
            dependencies: ["MeridianCore"],
            path: "Sources/Resilience",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MeridianCoreTests",
            dependencies: ["MeridianCore"],
            path: "Tests/MeridianCoreTests"
        ),
        .testTarget(
            name: "ResilienceTests",
            dependencies: ["MeridianCore", "Resilience"],
            path: "Tests/ResilienceTests"
        )
    ]
)
