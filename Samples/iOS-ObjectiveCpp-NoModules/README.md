# iOS-ObjectiveCpp-NoModules

This sample demonstrates **using the Sentry SDK from Objective-C++ when `-fmodules` and `-fcxx-modules` are not supported**.

Originally documented the issue in [getsentry/sentry-cocoa#4543](https://github.com/getsentry/sentry-cocoa/issues/4543). Now demonstrates the solution via **SentryObjC**.

## Problem

Many projects cannot enable Clang modules:

- **React Native** (≤0.76): AppDelegate is `.mm` (Objective-C++), modules disabled by default
- **Haxe**: Build toolchain conflicts with `-fmodules` / `-fcxx-modules`
- **Custom build systems**: May not support module imports

With modules disabled:

- `@import Sentry` does not work (requires modules)
- `#import <Sentry/Sentry.h>` exposes only the ObjC headers, not Swift APIs
- `#import <Sentry/Sentry-Swift.h>` fails with forward declaration errors (e.g. `UIView`, `UIWindowLevel`) when included from `.mm` files

**Result:** `SentrySDK`, `SentryOptions`, `options.sessionReplay` and other Swift-bridged APIs are unavailable. The SDK is effectively unusable from ObjC++ without modules.

## Solution: SentryObjC

The **SentryObjC** product (introduced in [#6342](https://github.com/getsentry/sentry-cocoa/issues/6342)) provides a pure Objective-C wrapper around the main SDK:

```objc
#import <SentryObjC/SentryObjC.h>  // Pure ObjC - no Swift modules required

[SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
    options.dsn = @"...";
    options.tracesSampleRate = @1.0;
    options.sessionReplay.sessionSampleRate = 0;  // All Swift APIs now available!
}];
```

**Key differences from the main Sentry framework:**

- ✅ Pure Objective-C public interface
- ✅ No Swift modules or `Sentry-Swift.h` required
- ✅ Works in Objective-C++ (`.mm` files) without modules
- ✅ Full access to all SDK features (SentrySDK, SentryOptions, sessionReplay, etc.)

## This Sample

- Uses **Objective-C++** (`.mm` files) for AppDelegate and ViewController
- Sets **`CLANG_ENABLE_MODULES = NO`** in the build configuration
- Depends on **SentryObjC** (SPM product) and imports `#import <SentryObjC/SentryObjC.h>`
- Builds successfully with full access to SentrySDK, SentryOptions, sessionReplay, etc.

## Generating the Project

```bash
cd Samples/iOS-ObjectiveCpp-NoModules
xcodegen generate
```

Or from the repo root:

```bash
make build-sample-iOS-ObjectiveCpp-NoModules
```
