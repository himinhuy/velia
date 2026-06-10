// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VeliaCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "VeliaCore", targets: ["VeliaCore"]),
        .executable(name: "velia-bench", targets: ["velia-bench"]),
    ],
    targets: [
        // Pure-Swift domain + prediction engine. NO UIKit, NO GRDB, NO networking.
        .target(name: "VeliaCore"),
        .executableTarget(name: "velia-bench", dependencies: ["VeliaCore"]),
        .testTarget(name: "VeliaCoreTests", dependencies: ["VeliaCore"]),
    ]
)
