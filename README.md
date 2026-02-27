<div align="center">
    <a href="https://sentry.io/?utm_source=github&utm_medium=logo" target="_blank">
        <img src="https://sentry-brand.storage.googleapis.com/github-banners/github-sdk-cocoa.jpg" alt="Sentry for Apple">
    </a>
</div>

_Bad software is everywhere, and we're tired of it. Sentry is on a mission to help developers write better software faster, so we can get back to enjoying technology. If you want to join us [<kbd>**Check out our open positions**</kbd>](https://sentry.io/careers/)_

> [!NOTE]
> You are currently viewing the **`main`** branch which contains the upcoming **v9** release with breaking changes.
>
> For the stable **v8** release, please switch to the [`v8.x` branch](https://github.com/getsentry/sentry-cocoa/tree/v8.x) and refer to the [v8 CHANGELOG](https://github.com/getsentry/sentry-cocoa/blob/v8.x/CHANGELOG.md).

# Official Sentry SDK for iOS / iPadOS / tvOS / macOS / watchOS <sup>(1)</sup> / visionOS

[![Build](https://img.shields.io/github/actions/workflow/status/getsentry/sentry-cocoa/build.yml?branch=main)](https://github.com/getsentry/sentry-cocoa/actions/workflows/build.yml?query=branch%3Amain)
[![codecov.io](https://codecov.io/gh/getsentry/sentry-cocoa/branch/master/graph/badge.svg)](https://codecov.io/gh/getsentry/sentry-cocoa)
[![SwiftPM compatible](https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat)](https://swift.org/package-manager)
[![Swift Package Index](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgetsentry%2Fsentry-cocoa%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/getsentry/sentry-cocoa)
[![X Follow](https://img.shields.io/twitter/follow/sentry?label=sentry&style=social)](https://x.com/intent/follow?screen_name=sentry)
[![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.com/invite/sentry)

# Installation

SPM is the recommended way to include Sentry into your project. We also provide pre-built XCFrameworks on [our GitHub Releases page](https://github.com/getsentry/sentry-cocoa/releases).

> [!WARNING]
> CocoaPods support has been deprecated and will no longer receive updates after July 2026. Please migrate to SPM or XCFrameworks. See [CocoaPods read-only change](https://blog.cocoapods.org/CocoaPods-Support-Plans/).

# Initialization

_Remember to call this as early in your application life cycle as possible_
Ideally in `applicationDidFinishLaunching` in `AppDelegate`

```swift
import Sentry

// ....

SentrySDK.start { options in
    options.dsn = "___PUBLIC_DSN___"
    options.debug = true // Helpful to see what's going on
}
```

```objc
@import Sentry;

// ....

[SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
    options.dsn = @"___PUBLIC_DSN___";
    options.debug = @YES; // Helpful to see what's going on
}];
```

For more information checkout the [docs](https://docs.sentry.io/platforms/apple).

<sup>(1)</sup>limited symbolication support and no crash handling.

# Resources

- [![Documentation](https://img.shields.io/badge/documentation-sentry.io-green.svg)](https://docs.sentry.io/platforms/apple/)
- [![Discussions](https://img.shields.io/github/discussions/getsentry/sentry-cocoa.svg)](https://github.com/getsentry/sentry-cocoa/discussions)
- [![Discord Chat](https://img.shields.io/discord/621778831602221064?logo=discord&logoColor=ffffff&color=7389D8)](https://discord.com/invite/sentry)
- [![Code of Conduct](https://img.shields.io/badge/code%20of%20conduct-sentry-green.svg)](https://github.com/getsentry/.github/blob/master/CODE_OF_CONDUCT.md)
- [![Twitter Follow](https://img.shields.io/twitter/follow/sentry?label=sentry&style=social)](https://twitter.com/intent/follow?screen_name=sentry)
