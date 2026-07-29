// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v15), .macOS(.v10_14), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(name: "Sentry-Static", targets: ["Sentry-Static", "SentryCppHelper"]),
        .library(name: "SentryObjC-Static", targets: ["SentryObjC-Static"])
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "Sentry-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.1/Sentry.xcframework.zip",
            checksum: "8e5fbdffbb3f001849932c9bd605489271450e0f9d2ba9c4b438b060f5aab30b" //Sentry-Static
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.23.1-alpha.1/SentryObjC-Static.xcframework.zip",
            checksum: "3371ea1f4ccde1e01b8476791bc0911062aa12bf7c6d5b2eac621595bc35c66f" //SentryObjC-Static
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
