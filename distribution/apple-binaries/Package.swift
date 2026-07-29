// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(name: "Sentry-Static", targets: ["Sentry-Static", "SentryCppHelper"]),
        .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
        .library(name: "SentryObjC-Dynamic", targets: ["SentryObjC-Dynamic"]),
        .library(name: "SentryObjC-Static", targets: ["SentryObjC-Static"])
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "Sentry-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.0/Sentry.xcframework.zip",
            checksum: "a518c68211d5845d524444ee81a83abf8121b82eb9c4cefa611d9e2fac4046fe" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.0/Sentry-Dynamic.xcframework.zip",
            checksum: "3b9b36fae6912576e81efadc1d2d6022f03882087bc1b71cd3c10993dc8da464" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.0/SentryObjC-Dynamic.xcframework.zip",
            checksum: "5c179e73dc024bd3caf11a6bdb34122e50a30de7b48fb869fcc33a6139f95dff" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.0/SentryObjC-Static.xcframework.zip",
            checksum: "1a7db0ead88b1200a841fa59ec9b59440613e0b684ecb80eed95d428bd964ddb" //SentryObjC-Static
        ),
        .target(
            name: "SentryCppHelper",
            path: "Sources/SentryCppHelper",
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        )
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
