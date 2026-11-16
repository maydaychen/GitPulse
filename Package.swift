// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GiteaKit",
    platforms: [
        .iOS("26.0"),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "GiteaKit",
            targets: ["GiteaKit"]
        )
    ],
    targets: [
        .target(
            name: "GiteaKit",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "GiteaKitTests",
            dependencies: ["GiteaKit"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        )
    ]
)
