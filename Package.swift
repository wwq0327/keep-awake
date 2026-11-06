// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "keep-awake",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "keep-awake", targets: ["KeepAwake"])
    ],
    targets: [
        .executableTarget(
            name: "KeepAwake",
            path: "Sources/KeepAwake",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(name: "KeepAwakeTests", dependencies: ["KeepAwake"])
    ]
)
