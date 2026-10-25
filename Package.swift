// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-escpos",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
    products: [
        .library(name: "SwiftESCPOS", targets: ["SwiftESCPOS"]),
    ],
    targets: [
        .target(
            name: "SwiftESCPOS",
        ),
        .testTarget(
            name: "SwiftESCPOSTests",
            dependencies: ["SwiftESCPOS"],
        ),
    ]
)
