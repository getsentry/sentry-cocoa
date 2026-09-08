# Build Configuration

This document covers the build system and configuration details for the Sentry Cocoa SDK.

### SDK Build Configuration

- XCConfig files in `Sources/Configuration/` for SDK settings; settings should not be modified in pbxproj files

## SDK Test Configurations

The Xcode project's `Test`, `TestV10`, and `TestCI` configurations enable SDK test helpers through `SENTRY_TEST` or `SENTRY_TEST_CI` in [SDK.xcconfig](../Sources/Configuration/SDK.xcconfig). Swift 6.1+ provides the opt-in `_SentryTest` and `_SentryTestCI` traits for local `swift test` invocations. Swift 6.0 and `xcodebuild` package-workspace tests continue to supply these flags explicitly at the call site; see [SwiftPM SDK Tests](TEST.md#swiftpm-sdk-tests). Do not enable test traits or flags in normal package builds.

## SwiftPM Test Targets

All active package manifests include `SentryObjCCompatTests` alongside the test utility suite, without adding test-support targets to SDK products. Both default and V10 builds are supported. Wrapper Swift compiler features are declared in the manifests for both builds and tests. Project-equivalent package-workspace tests use `-configuration Test` (or `TestCI`) with the opt-in `Tests/Configuration/SwiftPM.xcconfig` to match test compilation, library evolution, and Sentry-owned targets' diagnostics without overriding dependency warning policies. They also require explicit SDK test compiler flags and source-only package preparation; see [SwiftPM Objective-C Wrapper Tests](TEST.md#swiftpm-objective-c-wrapper-tests) and [compiler settings and project parity](TEST.md#compiler-settings-and-project-parity).

## UIKit Linking Control

Some customers would like to not link UIKit for various reasons. Either they simply may not want to use our UIKit functionality, or they actually cannot link to it in certain circumstances, like a File Provider app extension.

There are two build configurations they can use for this: `DebugWithoutUIKit` and `ReleaseWithoutUIKit`, that are essentially the same as `Debug` and `Release` with the following differences:

- They set `CLANG_MODULES_AUTOLINK` to `NO`. This avoids a load command being automatically inserted for any UIKit API that make their way into the type system during compilation of SDK sources.
- `GCC_PREPROCESSOR_DEFINITIONS` has an additional setting `SENTRY_NO_UI_FRAMEWORK=1`. This is now part of the definition of `SENTRY_HAS_UIKIT` in `SentryDefines.h` that is used to conditionally compile out any code that would otherwise use UIKit API and cause UIKit to be automatically linked as described above. There is another macro `SENTRY_UIKIT_AVAILABLE` defined as `SENTRY_HAS_UIKIT` used to be, meaning simply that compilation is targeting a platform where UIKit is available to be used. This is used in headers we deliver in the framework bundle to compile out declarations that rely on UIKit, and their corresponding implementations are switched over `SENTRY_HAS_UIKIT` to either provide the logic for configurations that link UIKit, or to provide a stub delivering a default value (`nil`, `0.0`, `NO` etc) and a warning log for publicly facing things like SentryOptions, or debug log for internal things like SentryDependencyContainer.

There are two jobs in `.github/workflows/build.yml` that will build each of the new configs and use `otool -L` to ensure that UIKit does not appear as a load command in the build products.

This feature is experimental and is currently not compatible with SPM.

## Build System Commands

```bash
make build-xcframework-dynamic  # Build Sentry-Dynamic XCFramework
./scripts/bump-version.sh --version X.Y.Z # Bump version
```

## Platform-Specific Build Notes

### visionOS Considerations

- Requires `SWIFT_OBJC_INTEROP_MODE=objcxx` for static framework
- Cannot call C functions directly from Swift with visionOS settings
- Special handling required for mixed Swift/Objective-C code

### SPM Limitations

- Uses pre-built binaries for faster builds and mixed-language limitations
- Binary distribution via git release assets
- Not compatible with UIKit-free configurations
