// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DataStructuresSwift",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "DataStructures",
            targets: ["DataStructures"]
        ),
        .library(
            name: "Resilience",
            targets: ["Resilience"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DataStructures",
            dependencies: [],
            path: "Sources/DataStructures",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "Resilience",
            dependencies: ["DataStructures"],
            path: "Sources/Resilience",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "DataStructuresTests",
            dependencies: ["DataStructures"],
            path: "Tests/DataStructuresTests"
        ),
        .testTarget(
            name: "ResilienceTests",
            dependencies: ["DataStructures", "Resilience"],
            path: "Tests/ResilienceTests"
        )
    ]
)
