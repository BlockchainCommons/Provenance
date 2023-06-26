// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Provenance",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .macCatalyst(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Provenance",
            targets: ["Provenance"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.7.2"),
         .package(url: "https://github.com/BlockchainCommons/URKit", from: "11.2.2"),
         .package(url: "https://github.com/wolfmcnally/WolfBase", from: "5.3.1"),
         .package(url: "https://github.com/wolfmcnally/WolfLorem", from: "2.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Provenance",
            dependencies: ["CryptoSwift", "URKit", "WolfBase"]),
        .testTarget(
            name: "ProvenanceTests",
            dependencies: ["Provenance", "WolfLorem"]),
    ]
)
