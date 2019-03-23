// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Starburst",
    products: [
        .library(
            name: "Starburst",
            targets: ["Starburst"]),
        ],
    targets: [
        .target(
            name: "Starburst")
        ]
)
