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
            name: "PhantomSwiftNetworking",
            dependencies: [],
            path: "Sources/PhantomSwiftNetworking"
        ),
        .target(
            name: "PhantomSwift",
            dependencies: ["PhantomSwiftNetworking"],
            path: "Sources/PhantomSwift"
        ),
        .testTarget(
            name: "PhantomSwiftTests",
            dependencies: ["PhantomSwift"],
            path: "Tests/PhantomSwiftTests"
        )
    ]
)
