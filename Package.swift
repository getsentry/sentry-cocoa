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
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.51.0/Sentry.xcframework.zip",
                    checksum: "41a737388793ec2c4b6a115ca45323066c22d3389ecb057de67133947f741d20" //Sentry-Static
                ),
        .binaryTarget(
                    name: "Sentry-Dynamic",
                    url: "https://github.com/getsentry/sentry-cocoa/releases/download/8.51.0/Sentry-Dynamic.xcframework.zip",
                    checksum: "7627709e6ed2203362dac81521064233d117c956be02c18fe077604d197d13e4" //Sentry-Dynamic
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
               ),
        .target(name: "SentryCoreSwift", path: "Sources/Swift/Core"),
        // The name of this package is _SentryPrivate so that it matches the imports already used in Swift code to access ObjC.
        .target(name: "_SentryPrivate", dependencies: ["SentryCoreSwift"], path: "Sources/Sentry/_SentryPrivate", cSettings: [.headerSearchPath("Public")])
    ],
    cxxLanguageStandard: .cxx14
)
