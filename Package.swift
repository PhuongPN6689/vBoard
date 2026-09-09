// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "vBoard",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "vBoardEngine",
            targets: ["vBoardEngine"]
        ),
        .library(
            name: "vBoardKeyboard",
            targets: ["vBoardKeyboard"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "vBoardEngine",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "vBoardKeyboard",
            dependencies: ["vBoardEngine"]
        ),
        .testTarget(
            name: "vBoardEngineTests",
            dependencies: ["vBoardEngine"]
        ),
    ]
)
