// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "Sentry-Static", targets: ["Sentry-Static", "SentryCppHelper"]),
        .library(name: "SentryObjC-Static", targets: ["SentryObjC-Static"])
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "Sentry-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.1/Sentry.xcframework.zip",
            checksum: "0e6ac8c8e0661e54ed9d30a84a45a730bf08e9499800afc63cb8be2a61e7adcf" //Sentry-Static
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.29.1/SentryObjC-Static.xcframework.zip",
            checksum: "859b44905b11e7710743c71c5463ab3d119261457cf914e1326bd5bb9dbb8476" //SentryObjC-Static
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
