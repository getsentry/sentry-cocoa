import PackageDescription

let package = Package(
    name: "sentry",
    dependencies : [],
    exclude: [
        "Sources/Sentry/KSCrash",
        "Sources/Sentry/ios"
    ]
)
