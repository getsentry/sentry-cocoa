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
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.0/Sentry.xcframework.zip",
            checksum: "e16f1fb6333f572e980be28d2a9e1ea20a08c2c91b7901d612ff6cee2af697cf" //Sentry-Static
        ),
        .binaryTarget(
            name: "Sentry-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.0/Sentry-Dynamic.xcframework.zip",
            checksum: "0693709291e8713c189b3c2407cc87885aca57819d3356710ea04e9076dfdd26" //Sentry-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Dynamic",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.0/SentryObjC-Dynamic.xcframework.zip",
            checksum: "23faa002b65d60185fa3a157c0febc2be27ff5b1f69d02718fb1a0843e295680" //SentryObjC-Dynamic
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.0/SentryObjC-Static.xcframework.zip",
            checksum: "85f70dbfef220f347934ce660b955f094065cc0b0bf555b93eb57205efcc9121" //SentryObjC-Static
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
