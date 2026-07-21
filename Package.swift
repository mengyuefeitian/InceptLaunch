// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "InceptLaunch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "InceptLaunch", targets: ["InceptLaunch"])
    ],
    targets: [
        .executableTarget(
            name: "InceptLaunch",
            path: "Sources/InceptLaunch"
        ),
        .testTarget(
            name: "InceptLaunchTests",
            dependencies: ["InceptLaunch"],
            path: "Tests/InceptLaunchTests"
        )
    ]
)
