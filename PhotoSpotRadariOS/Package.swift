// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhotoSpotCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "PhotoSpotCore", targets: ["PhotoSpotCore"])],
    targets: [
        .target(name: "PhotoSpotCore"),
        .testTarget(name: "PhotoSpotCoreTests", dependencies: ["PhotoSpotCore"])
    ]
)
