// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CoachingKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CoachingKit", targets: ["CoachingKit"])
    ],
    targets: [
        .target(name: "CoachingKit"),
        .testTarget(name: "CoachingKitTests", dependencies: ["CoachingKit"])
    ]
)
