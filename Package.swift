// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Sentry",
    platforms: [.iOS(.v11), .macOS(.v10_13), .tvOS(.v11), .watchOS(.v4)],
    products: [
        .library(name: "Sentry", targets: ["Sentry"]),
        .library(name: "SentrySwiftUI", targets: ["SentrySwiftUI"])
    ],
    targets: [
        .binaryTarget(
                    name: "Sentry",
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.21.0-beta.0/Sentry.xcframework.zip",
                    checksum: "f718d2cec8bf47a5c66248658ab25743ef7b1a658004f3467e42f4cd3610e56f"
                ),
        .target ( name: "SentrySwiftUI",
                  dependencies: ["Sentry", "SentryInternal"],
                  path: "Sources",
                  exclude: ["SentrySwiftUI/SentryInternal/"],
                  sources: [
                    "SentrySwiftUI"
                  ]
                ),
        //SentryInternal is how we expose some internal Sentry SDK classes to SentrySwiftUI.
        .target( name: "SentryInternal",
                 path: "Sources",
                 sources: [
                    "SentrySwiftUI/SentryInternal/"
                 ],
                 publicHeadersPath: "SentrySwiftUI/SentryInternal/"
               )
    ],
    cxxLanguageStandard: .cxx14
)
