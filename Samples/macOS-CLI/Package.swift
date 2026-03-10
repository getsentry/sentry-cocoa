// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "macOS-CLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "cli-with-binary", targets: ["cli-with-binary"]),
        .executable(name: "cli-with-spm", targets: ["cli-with-spm"])
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", exact: "1.24.2"),
        .package(name: "sentry-cocoa", path: "../../")
    ],
    targets: [
        .executableTarget(name: "cli-with-binary", dependencies: [
            .product(name: "GRPC", package: "grpc-swift"),
            .product(name: "Sentry", package: "sentry-cocoa")
        ]),
        .executableTarget(name: "cli-with-spm", dependencies: [
            .product(name: "GRPC", package: "grpc-swift"),
            .product(name: "SentrySPM", package: "sentry-cocoa")
        ])
    ],
)
