// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "Starburst",
    products: [
        .library(
            name: "Starburst",
            targets: ["Starburst"]),
        ],
    dependencies: [
        .package(url: "https://github.com/vrisch/Orbit.git", .branch("master")),
        ],
    targets: [
        .target(
            name: "Starburst",
            dependencies: ["Orbit"]),
        ]
)
