// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4)],
    products: [
        .library(name: "Sentry", targets: ["Sentry"]),
        .library(name: "Sentry-Dynamic", targets: ["Sentry-Dynamic"]),
        .library(name: "SentrySwiftUI", targets: ["Sentry", "SentrySwiftUI"])
    ],
    targets: [
        .binaryTarget(
                    name: "Sentry",
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.42.1/Sentry.xcframework.zip",
                    checksum: "bc6cfefcc31c2e0558442688d6de1410df5b871c130f09886ba3976d2ae266f2" //Sentry-Static
                ),
        .binaryTarget(
                    name: "Sentry-Dynamic",
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.42.1/Sentry-Dynamic.xcframework.zip",
                    checksum: "eab78a259883648a624a0d6bcc508af2fc2166cee117afebd6031dbee68b75ec" //Sentry-Dynamic
                ),
        .target ( name: "SentrySwiftUI",
                  dependencies: ["Sentry", "SentryInternal"],
                  path: "Sources/SentrySwiftUI",
                  exclude: ["SentryInternal/", "module.modulemap"],
                  linkerSettings: [
                     .linkedFramework("Sentry")
                  ]
                ),
        .target( name: "SentryInternal",
                 path: "Sources/SentrySwiftUI",
                 sources: [
                    "SentryInternal/"
                 ],
                 publicHeadersPath: "SentryInternal/"
               )
    ],
    cxxLanguageStandard: .cxx14
)
