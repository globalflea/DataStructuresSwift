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
        // Pure 2D Vector Geometry & Mathematical Foundations
        .library(
            name: "VectorGeometry",
            targets: ["VectorGeometry"]
        ),
        // Animation, Easing Equations & Interpolation Tweens
        .library(
            name: "VectorAnimation",
            targets: ["VectorAnimation"]
        ),
        // Graph & Tree Auto-Layout Solvers
        .library(
            name: "VectorLayout",
            targets: ["VectorLayout"]
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
        .target(
            name: "VectorGeometry",
            dependencies: [],
            path: "Sources/VectorGeometry",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "VectorAnimation",
            dependencies: ["VectorGeometry"],
            path: "Sources/VectorAnimation",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "VectorLayout",
            dependencies: ["VectorGeometry"],
            path: "Sources/VectorLayout",
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
        ),
        .testTarget(
            name: "VectorGeometryTests",
            dependencies: ["VectorGeometry"],
            path: "Tests/VectorGeometryTests"
        ),
        .testTarget(
            name: "VectorAnimationTests",
            dependencies: ["VectorGeometry", "VectorAnimation"],
            path: "Tests/VectorAnimationTests"
        ),
        .testTarget(
            name: "VectorLayoutTests",
            dependencies: ["VectorGeometry", "VectorLayout"],
            path: "Tests/VectorLayoutTests"
        )
    ]
)
