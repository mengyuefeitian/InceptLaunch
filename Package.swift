// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "iLaunch",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "iLaunch", targets: ["iLaunch"])
    ],
    targets: [
        .executableTarget(
            name: "iLaunch",
            path: "Sources/iLaunch"
        ),
        .testTarget(
            name: "iLaunchTests",
            dependencies: ["iLaunch"],
            path: "Tests/iLaunchTests"
        )
    ]
)
