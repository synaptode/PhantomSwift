// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PhantomSwift",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "PhantomSwift",
            targets: ["PhantomSwift"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PhantomSwift",
            dependencies: [],
            path: "Sources/PhantomSwift"
        )
    ]
)
