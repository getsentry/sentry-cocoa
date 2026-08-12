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
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.26.0/Sentry.xcframework.zip",
            checksum: "e1b80746e632d1127975b9ecca2d42398a74e4adac94882a71192eee41b1dc29" //Sentry-Static
        ),
        .binaryTarget(
            name: "SentryObjC-Static",
            url: "https://github.com/getsentry/sentry-cocoa/releases/download/9.26.0/SentryObjC-Static.xcframework.zip",
            checksum: "01f2c0d4ee41b82acae8c1274a40a06f6c9dbf1bba6e7a90ec213d4d39af740c" //SentryObjC-Static
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
