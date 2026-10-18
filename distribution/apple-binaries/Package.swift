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
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.2/Sentry.xcframework.zip",
            checksum: "593897dbdee24febeef45208b13960a4b389c5dbd25f64b1b3cb94c30291ed55" //Sentry-Static
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.30.2/SentryObjC-Static.xcframework.zip",
            checksum: "01c43031278b4c7e9f697254430542e4597e1175a0ce3ca648aa5e99eb2b8cd2" //SentryObjC-Static
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
