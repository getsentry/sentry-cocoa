# iOS-ObjectiveCpp-NoModules

This sample replicates the issue documented in [getsentry/sentry-cocoa#4543](https://github.com/getsentry/sentry-cocoa/issues/4543): **using the Sentry SDK from Objective-C++ when `-fmodules` and `-fcxx-modules` are not supported.**

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

## This Sample

- Uses **Objective-C++** (`.mm` files) for AppDelegate and ViewController
- Sets **`CLANG_ENABLE_MODULES = NO`** in the build configuration
- Uses only `#import <Sentry/Sentry.h>` in `.mm` files (does **not** import `Sentry-Swift.h`)
- Demonstrates that Swift-bridged APIs like `SentrySDK` and `options.sessionReplay` are unavailable from ObjC++ without modules

**Build status:** The sample **does NOT build** and reproduces the issue. With only `#import <Sentry/Sentry.h>` (no `Sentry-Swift.h`), the compiler reports `error: use of undeclared identifier 'SentrySDK'`. Attempting to include `#import <Sentry/Sentry-Swift.h>` in this setup (see comments in `AppDelegate.mm` / `ViewController.mm`) fails with forward declaration errors when used from `.mm` files without modules. The sample exists to:

1. Document the exact pattern that fails for ObjC++ consumers in production
2. Serve as a test case for the fix in [getsentry/sentry-cocoa#6342](https://github.com/getsentry/sentry-cocoa/issues/6342)

## Planned Fix (#6342)

Issue [#6342](https://github.com/getsentry/sentry-cocoa/issues/6342) proposes a **pure Objective-C SDK wrapper** that can be imported without modules. Once implemented, this sample should build successfully.

## Generating the Project

```bash
cd Samples/iOS-ObjectiveCpp-NoModules
xcodegen generate
```

Or from the repo root:

```bash
make xcode-ci  # regenerates all sample projects including this one
```
