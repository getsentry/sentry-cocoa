import PackageDescription

let package = Package(
    name: "Sentry",
    dependencies : [
      .Package(url: "https://github.com/vapor/vapor.git", majorVersion: 1, minor: 5)
    ],
    exclude: [
        "Sources/Sentry/KSCrash",
        "Sources/Sentry/ios"
    ]
)
