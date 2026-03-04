# iOS-ObjectiveCpp-NoModules

This sample demonstrates **using the Sentry SDK from Objective-C++ when `-fmodules` and `-fcxx-modules` are not supported**, via the pure ObjC wrapper (SentryObjC).

## Use Case

Many projects cannot enable Clang modules:

- **React Native** (≤0.76): AppDelegate is `.mm` (Objective-C++), modules disabled by default
- **Haxe**: Build toolchain conflicts with `-fmodules` / `-fcxx-modules`
- **Custom build systems**: May not support module imports

## Solution: SentryObjC

Use the **SentryObjC** product instead of the main Sentry framework:

```objc
#import <SentryObjC/SentryObjC.h>

[SentrySDK startWithConfigureOptions:^(SentryOptions *options) {
    options.dsn = @"...";
    options.tracesSampleRate = @1.0;
    options.sessionReplay.sessionSampleRate = 0;
}];
```

SentryObjC provides a pure Objective-C public interface. No Swift modules or `Sentry-Swift.h` are required.

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
