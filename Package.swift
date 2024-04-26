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
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.25.0-alpha.0/Sentry.xcframework.zip",
                    checksum: "1baa5774dc044d2e231eccb7e55601bd6a14d44d8bbd806562e85a15a4ef4c73" //Sentry-Static
                ),
        .binaryTarget(
                    name: "Sentry-Dynamic",
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.25.0-alpha.0/Sentry-Dynamic.xcframework.zip",
                    checksum: "897e6c47f6b27fe2e870aca5ecbf29d00792accd77d5a8c6d8ebbb5e3ab1062e" //Sentry-Dynamic
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
