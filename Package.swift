// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HarmonicCore",
    platforms: [.macOS(.v14), .iOS("27.0")],
    products: [.library(name: "HarmonicCore", targets: ["HarmonicCore"])],
    targets: [
        .target(name: "HarmonicCore"),
        .testTarget(name: "HarmonicCoreTests", dependencies: ["HarmonicCore"])
    ]
)
