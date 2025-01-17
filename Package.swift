// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Provenance",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .macCatalyst(.v16)
    ],
    products: [
        .library(
            name: "Provenance",
            targets: ["Provenance"]),
    ],
    dependencies: [
         .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.8.3"),
         .package(url: "https://github.com/BlockchainCommons/URKit", from: "15.1.0"),
         .package(url: "https://github.com/BlockchainCommons/BCSwiftRandom", from: "2.0.0"),
         .package(url: "https://github.com/wolfmcnally/WolfBase", from: "7.1.0"),
    ],
    targets: [
        .target(
            name: "Provenance",
            dependencies: [
                "CryptoSwift",
                "URKit",
                "WolfBase",
                .product(name: "BCRandom", package: "bcswiftrandom"),
            ]),
        .testTarget(
            name: "ProvenanceTests",
            dependencies: [
                "Provenance"
            ]),
    ]
)
