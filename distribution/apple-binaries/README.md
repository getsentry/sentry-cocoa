<div align="center">
    <a href="https://sentry.io/?utm_source=github&utm_medium=logo" target="_blank">
        <img src="https://sentry-brand.storage.googleapis.com/github-banners/github-sdk-cocoa.jpg" alt="Sentry for Apple">
    </a>
</div>

_Bad software is everywhere, and we're tired of it. Sentry is on a mission to help developers write better software faster, so we can get back to enjoying technology. If you want to join us [<kbd>**Check out our open positions**</kbd>](https://sentry.io/careers/)_

# Sentry Cocoa Binaries

[![SwiftPM compatible](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)
[![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.com/invite/sentry)

This repository distributes **pre-built XCFramework binaries** of the [Sentry Cocoa SDK](https://github.com/getsentry/sentry-cocoa) via Swift Package Manager.

If you want to build from source, use the main [sentry-cocoa](https://github.com/getsentry/sentry-cocoa) repository instead.

## Available Libraries

| Library             | Linking | Description               |
| ------------------- | ------- | ------------------------- |
| `Sentry-Static`     | Static  | Sentry SDK (Swift + ObjC) |
| `SentryObjC-Static` | Static  | Sentry SDK (ObjC only)    |

## Installation

Add this package to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/getsentry/sentry-cocoa-binaries.git", from: "9.22.0")
]
```

Then add the desired library product to your target's dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "Sentry-Static", package: "sentry-cocoa-binaries"),
    ]
)
```

For full installation options and integration guides, see the [Sentry Apple documentation](https://docs.sentry.io/platforms/apple/install/).

## Platform Support

iOS 15+, macOS 10.14+, tvOS 15+, watchOS 8+, visionOS 1+

## Resources

- [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/apple/)
- [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-cocoa.svg)](https://github.com/getsentry/sentry-cocoa/discussions)
- [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.com/invite/sentry)
- [![Code of Conduct](https://img.shields.io/badge/code%20of%20conduct-sentry-green.svg)](https://github.com/getsentry/.github/blob/master/CODE_OF_CONDUCT.md)
- [![X Follow](https://img.shields.io/twitter/follow/sentry?label=sentry&style=social)](https://x.com/intent/follow?screen_name=sentry)
