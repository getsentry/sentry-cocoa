import PackageDescription

let package = Package(
    name: "Sentry",
    exclude: [
        "Sources/Sentry/KSCrash",
        "Sources/Sentry/ios"
    ]
)
