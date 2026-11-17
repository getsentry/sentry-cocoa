# Build Configuration

This document covers the build system and configuration details for the Sentry Cocoa SDK.

### SDK Build Configuration

- XCConfig files in `Sources/Configuration/` for SDK settings; settings should not be modified in pbxproj files

## SDK Test Configurations

SDK tests use `Debug`, or `DebugV10` for V10 Xcode project builds. SwiftPM V10 tests also use `Debug`, with `SDK_V10=1` selecting the SDK implementation. Debug builds enable testability and SDK test helpers through `DEBUG`; no test traits or separate test configurations are required. Make/CI adds the [package test xcconfig](../Tests/Configuration/SwiftPM.xcconfig) for ABI and diagnostic checks. See [SwiftPM SDK Tests](TEST.md#swiftpm-sdk-tests). Release builds exclude debug/test helpers. Do not explicitly enable `DEBUG` in production builds.

## SwiftPM Test Targets

SwiftPM test targets are separate from published SDK products. The shared `SentrySPM` scheme uses Base test plans for the default and V10 development configurations. See [SwiftPM SDK Tests](TEST.md#swiftpm-sdk-tests) for local and CI commands and [compiler settings and project parity](TEST.md#compiler-settings-and-project-parity).

## UIKit Linking Control

Some customers would like to not link UIKit for various reasons. Either they simply may not want to use our UIKit functionality, or they actually cannot link to it in certain circumstances, like a File Provider app extension.

There are two build configurations they can use for this: `DebugWithoutUIKit` and `ReleaseWithoutUIKit`, that are essentially the same as `Debug` and `Release` with the following differences:

- They set `CLANG_MODULES_AUTOLINK` to `NO`. This avoids a load command being automatically inserted for any UIKit API that make their way into the type system during compilation of SDK sources.
- `GCC_PREPROCESSOR_DEFINITIONS` has an additional setting `SENTRY_NO_UI_FRAMEWORK=1`. This is now part of the definition of `SENTRY_HAS_UIKIT` in `SentryDefines.h` that is used to conditionally compile out any code that would otherwise use UIKit API and cause UIKit to be automatically linked as described above. There is another macro `SENTRY_UIKIT_AVAILABLE` defined as `SENTRY_HAS_UIKIT` used to be, meaning simply that compilation is targeting a platform where UIKit is available to be used. This is used in headers we deliver in the framework bundle to compile out declarations that rely on UIKit, and their corresponding implementations are switched over `SENTRY_HAS_UIKIT` to either provide the logic for configurations that link UIKit, or to provide a stub delivering a default value (`nil`, `0.0`, `NO` etc) and a warning log for publicly facing things like SentryOptions, or debug log for internal things like SentryDependencyContainer.

SwiftPM consumers use the `NoUIFramework` trait. The [Build workflow](../.github/workflows/build.yml) builds and tests the V10 macOS CLI with that trait and verifies that its executable links neither AppKit nor UIKit.

## Build System Commands

```bash
make build-xcframework-dynamic  # Build SentryV10-Dynamic XCFramework
./scripts/bump-version.sh --version X.Y.Z # Bump version
```

`build-xcframework-slice.sh` passes the complete release architecture list to the SDK and its KSCrash package dependencies. Dynamic builds use the SDK targets' default Mach-O type; a global `MACH_O_TYPE=mh_dylib` override would incorrectly turn package object aggregates into dynamic libraries. Static builds explicitly select `staticlib`.

`assemble-xcframework.sh` accepts per-SDK XCArchives (`--archive-template` and `--scheme`), standalone frameworks (`--framework-template`), or static libraries (`--library-template` and `--headers`). Each template substitutes `SDK_NAME` for each entry in `--sdks`. Standalone slices can use `--output` without a scheme. Assembly fails if the output already exists. See [SentryObjC Build Process](SENTRY-OBJC-BUILD.md) for the SwiftPM slice pipeline and its extra static-library validation.

The [Release workflow](../.github/workflows/release.yml) builds `Sentry`, `Sentry-Dynamic`, their `WithARM64e` variants, and both `SentryObjC` XCFrameworks from the V10 SDK. The `Sentry` slices run [`build-xcframework-v10.sh --slices-only`](../scripts/build-xcframework-v10.sh) with Xcode 26, which archives the `SentryV10` scheme as `Sentry.framework`. `Sentry-WithoutUIKitOrAppKit` still builds the V9 `Sentry` scheme with Xcode 16, because the Xcode project has no V10 configuration without UIKit yet.

### SPM-built SDK frameworks

Build a self-contained `Sentry-Dynamic.xcframework` from SwiftPM sources for either V9 or V10, matching the Xcode-project dynamic artifact name. The inner framework remains `Sentry.framework`. Swift binary consumers always use `import Sentry`; Objective-C binary consumers use `@import Sentry;`.

```bash
SDK_V10=0 make build-xcframework-spm SDKS=macosx FOR_AGENTS=true
SDK_V10=1 make build-xcframework-spm SDKS=macosx FOR_AGENTS=true
```

The [build script](../scripts/build-xcframework-variant-spm.sh) automatically sets the producer-only `SENTRY_BUILD_XCFRAMEWORK=1`. The manifests omit downloaded binary targets and compile the main SDK as module/product `Sentry`, without changing the crash backend (KSCrash in both configurations). Wrapper and test targets are excluded from this packaging graph; ordinary source builds remain unchanged. This setting is not required by consumers or defined in distributed public headers.

Output: `XCFrameworkBuildPath/SPM/v9/Sentry-Dynamic.xcframework.zip` or `XCFrameworkBuildPath/SPM/v10/Sentry-Dynamic.xcframework.zip`. The generation-specific directories keep intermediates and identically named artifacts separate. When overriding `SPM_XCFRAMEWORK_BUILD_PATH` (or the script’s `--output-dir`), use separate paths for each generation. See [input preparation](../scripts/prepare-sentry-framework-inputs.sh) for framework assembly details.

Both V9 binary producers compile the legacy Swift crash adapter into `Sentry` so existing `@_spi(Private) import Sentry` consumers retain their Swift symbol identities. The Release workflow on `main` no longer builds a V9 Xcode framework to check this against the SwiftPM framework.

Validate an unpacked macOS artifact locally. Neither consumer needs producer compiler settings:

```bash
for generation in v9 v10; do
  for consumer in SPM-Dynamic SPM-ObjC-Dynamic; do
    SENTRY_XCFRAMEWORK="../../XCFrameworkBuildPath/SPM/$generation/Sentry-Dynamic.xcframework" \
      swift run --package-path "TestApps/$consumer" --configuration release "$consumer"
  done
done
```

The Swift-only [`SPM-Dynamic`](../TestApps/SPM-Dynamic) sample checks public API, SPI, and the privacy manifest from the loaded SDK bundle. The Objective-C-only [`SPM-ObjC-Dynamic`](../TestApps/SPM-ObjC-Dynamic) sample checks ordinary Objective-C imports, public API, and version exports. Both verify dynamic loading without starting integrations or sending network requests. Without `SENTRY_XCFRAMEWORK`, both consume the existing `Sentry-Dynamic` product; use `swift run --build-system xcode --package-path "TestApps/$consumer" "$consumer"` for each sample as in the Release workflow.

The [Release workflow](../.github/workflows/release.yml) runs macOS V9/V10 packaging and isolated consumer checks as **advisory** jobs; SPM artifacts are not published. Switching releases requires platform/API parity and mandatory packaging/consumer gates.

## Public API Generation

> [!NOTE]
> The public API snapshots, including `sdk_api.json`, track SDK v10. SDK v9 is being removed incrementally and is no longer covered by API stability checks.

`make generate-public-api` runs [`update-api.sh`](../scripts/update-api.sh) with Xcode 16. It generates API snapshots: `sdk_api.json` for the Xcode framework, `sdk_api_spm.json` for the [SPM-built framework](#spm-built-sdk-frameworks), and `sdk_api_objc.json` and `sdk_api_objc.diff.json` for the ObjC wrappers and their drift.

The [API stability workflow](../.github/workflows/api-stability.yml) runs the same target and fails if a checked-in snapshot differs from the regenerated API.

Both the Xcode and SwiftPM paths build iPhoneOS XCFrameworks, then use the same extractor on their packaged `Sentry` framework slices. SwiftPM artifacts are built in `DerivedData/API-SPM-V10`. Private SPI interfaces are removed before analysis. The complete generated JSON snapshots are the source of truth: the command fails if the SwiftPM snapshot differs from its Xcode counterpart, including imports, attributes, and nested signatures.

Both builds declare the Swift sampler callback alias. SwiftPM packaging reuses Xcode's `Sentry.h` umbrella and resolves header conditionals with `unifdef`, matching `SentryV10.xcconfig`, without exposing configuration macros or extra public submodules.

## Platform-Specific Build Notes

### visionOS Considerations

- Requires `SWIFT_OBJC_INTEROP_MODE=objcxx` for static framework
- Cannot call C functions directly from Swift with visionOS settings
- Special handling required for mixed Swift/Objective-C code

### SPM Limitations

- Uses pre-built binaries for faster builds and mixed-language limitations
- Binary distribution via git release assets
- Use the `NoUIFramework` trait for source builds without UIKit/AppKit linkage

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

For ordinary source builds, shared SDK and test code imports `SentrySwift` under `#if SWIFT_PACKAGE && !SDK_V10` and `Sentry` otherwise. The packaging-only mode above also selects `Sentry`, using explicit `SENTRY_BUILD_XCFRAMEWORK` compiler conditions for internal imports. Do not use `canImport` to select a version or module name: cached modules can survive mode switches.

Source-based test apps use V10 product references and app compiler definitions in their checked-in XcodeGen specs. The build and test commands for these apps set `SDK_V10=1` for SwiftPM. Project generation does not require this environment setting. Use `make xcode` to generate projects and open Xcode with the V10 package graph. Direct Xcode invocations also need `SDK_V10=1`. Binary-distribution validation and CrashE2E retain their separate generation coverage.

### Build and test coverage

The standard SDK and V10 development workflows build and test KSCrash on the supported platforms. The V10 build workflow also packages static/dynamic SDK and Objective-C wrapper products, builds generated source consumers, and runs CLI subprocess and NoUI linkage checks. Packaging targets use the shared XCFramework validators; Objective-C static libraries additionally use the wrapper-specific static integration check.

Use the existing [SDK tests](TEST.md), [CrashE2E](../TestApps/CrashE2E/README.md), and [SentryObjC build targets](SENTRY-OBJC-BUILD.md) to validate behavior and distributed artifacts. The retired recorder's source/empty-object migration checks are no longer part of SDK builds or CI.
