# Build Configuration

This document covers the build system and configuration details for the Sentry Cocoa SDK.

### SDK Build Configuration

- XCConfig files in `Sources/Configuration/` for SDK settings; settings should not be modified in pbxproj files

## SDK Test Configurations

The Xcode project's `Test`, `TestV10`, and `TestCI` configurations enable SDK test helpers through `SENTRY_TEST` or `SENTRY_TEST_CI` in [SDK.xcconfig](../Sources/Configuration/SDK.xcconfig). Swift 6.1+ provides the opt-in `_SentryTest` and `_SentryTestCI` traits for local `swift test` invocations. Swift 6.0 and `xcodebuild` package-workspace tests continue to supply these flags explicitly at the call site; see [SwiftPM SDK Tests](TEST.md#swiftpm-sdk-tests). Do not enable test traits or flags in normal package builds.

## SwiftPM Test Targets

SwiftPM test targets are separate from published SDK products. The shared `SentrySPM` scheme uses Base test plans for the default and V10 development configurations. See [SwiftPM SDK Tests](TEST.md#swiftpm-sdk-tests) for local and CI commands and [compiler settings and project parity](TEST.md#compiler-settings-and-project-parity).

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

`build-xcframework-slice.sh` passes the complete release architecture list to the SDK and its KSCrash package dependencies. Dynamic builds use the SDK targets' default Mach-O type; a global `MACH_O_TYPE=mh_dylib` override would incorrectly turn package object aggregates into dynamic libraries. Static builds explicitly select `staticlib`.

`assemble-xcframework.sh` accepts per-SDK XCArchives (`--archive-template` and `--scheme`), standalone frameworks (`--framework-template`), or static libraries (`--library-template` and `--headers`). Each template substitutes `SDK_NAME` for each entry in `--sdks`. Standalone slices can use `--output` without a scheme. Assembly fails if the output already exists. See [SentryObjC Build Process](SENTRY-OBJC-BUILD.md) for the SwiftPM slice pipeline and its extra static-library validation.

## Platform-Specific Build Notes

### visionOS Considerations

- Requires `SWIFT_OBJC_INTEROP_MODE=objcxx` for static framework
- Cannot call C functions directly from Swift with visionOS settings
- Special handling required for mixed Swift/Objective-C code

### SPM Limitations

- Uses pre-built binaries for faster builds and mixed-language limitations
- Binary distribution via git release assets
- Not compatible with UIKit-free configurations

## Crash Handling

The source SDK uses KSCrash with or without `SDK_V10`. The previously bundled SentryCrash recorder and its adapters, headers, targets and tests have been removed. SDK-side compatibility interfaces remain, including `SentryCrashExceptionApplication`, the Unity C++ handoff, scope sync, report conversion and stack mapping. That might change until the release of V10.

> [!NOTE]
> Unrelated V10 development settings and source-product/module names stay until the coordinated cutover. These settings no longer select a crash backend. Existing published binary products are not rebuilt by changing the source checkout. See [decision 40](DECISIONS.md#40-develop-v10-on-main-then-branch-off-v9) for the release boundary.

### SwiftPM V10 selection

Use `SDK_V10=1` for V10 development compiler settings and the `Sentry` source product. KSCrash dependencies are unconditional. There is no backend-version trait and unrelated traits stay unchanged. See [decision 41](DECISIONS.md#41-select-swiftpm-v10-through-the-environment-only) for the development naming rationale.

| Selection      | Recorder | Source product / Swift module |
| -------------- | -------- | ----------------------------- |
| No `SDK_V10=1` | KSCrash  | `SentrySPM` / `SentrySwift`   |
| `SDK_V10=1`    | KSCrash  | `Sentry` / `Sentry`           |

Shared SDK and test code imports `SentrySwift` under `#if SWIFT_PACKAGE && !SDK_V10` and `Sentry` otherwise. Do not use `canImport` to select a version: cached modules can survive mode switches.

`make switch-v10`, `make build-testapp-v10-*`, and `make test-testapp-v10-macOS-CLI-Xcode` export the environment for generation and building. The generator selects the source product and sets app-target compiler definitions. Direct generator or Xcode invocations also need `SDK_V10=1`.

### Build and test coverage

The standard SDK and V10 development workflows build and test KSCrash on the supported platforms. The V10 build workflow also packages static/dynamic SDK and Objective-C wrapper products, builds generated source consumers, and runs CLI subprocess and NoUI linkage checks. Packaging targets use the shared XCFramework validators; Objective-C static libraries additionally use the wrapper-specific static integration check.

Use the existing [SDK tests](TEST.md), [CrashE2E](../TestApps/CrashE2E/README.md), and [SentryObjC build targets](SENTRY-OBJC-BUILD.md) to validate behavior and distributed artifacts. The retired recorder's source/empty-object migration checks are no longer part of SDK builds or CI.
