// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// SwiftNIO, needed only by `SwiftESCPOSNetwork` and only with the `Network` trait. Without the
/// trait, swift-nio is neither fetched nor resolved.
let nio: [Target.Dependency] = ["NIOCore", "NIOPosix", "NIOConcurrencyHelpers"].map {
    .product(name: $0, package: "swift-nio", condition: .when(traits: ["Network"]))
}

let package = Package(
    name: "swift-escpos",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
    products: [
        .library(name: "SwiftESCPOS", targets: ["SwiftESCPOS"]),
        // Empty unless the `Network` trait is enabled: SwiftPM cannot make a product conditional.
        .library(name: "SwiftESCPOSNetwork", targets: ["SwiftESCPOSNetwork"]),
    ],
    traits: [
        .trait(name: "Network", description: "TCP printing and status queries over SwiftNIO, in SwiftESCPOSNetwork."),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        // Pure ESC/POS encoding and status parsing: no dependencies, no I/O.
        .target(name: "SwiftESCPOS"),
        // TCP transport and status queries, on SwiftNIO.
        .target(
            name: "SwiftESCPOSNetwork",
            dependencies: ["SwiftESCPOS"] + nio
        ),
        .testTarget(
            name: "SwiftESCPOSTests",
            dependencies: ["SwiftESCPOS"]
        ),
        .testTarget(
            name: "SwiftESCPOSNetworkTests",
            dependencies: ["SwiftESCPOS", "SwiftESCPOSNetwork"] + nio
        ),
    ],
    swiftLanguageModes: [.v6]
)
