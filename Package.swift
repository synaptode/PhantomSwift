// swift-tools-version:5.3
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
