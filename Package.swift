// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-escpos",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
    products: [
        .library(name: "SwiftESCPOS", targets: ["SwiftESCPOS"]),
        .library(name: "SwiftESCPOSNetwork", targets: ["SwiftESCPOSNetwork"]),
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
            dependencies: [
                "SwiftESCPOS",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "SwiftESCPOSTests",
            dependencies: ["SwiftESCPOS"]
        ),
        .testTarget(
            name: "SwiftESCPOSNetworkTests",
            dependencies: [
                "SwiftESCPOS",
                "SwiftESCPOSNetwork",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
