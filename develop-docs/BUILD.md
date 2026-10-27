# Build Configuration

This document covers the build system and configuration details for the Sentry Cocoa SDK.

### SDK Build Configuration

- XCConfig files in `Sources/Configuration/` for SDK settings; settings should not be modified in pbxproj files

## SDK Test Configurations

The Xcode project's `Test`, `TestV10`, and `TestCI` configurations enable SDK test helpers through `SENTRY_TEST` or `SENTRY_TEST_CI` in [SDK.xcconfig](../Sources/Configuration/SDK.xcconfig). Swift 6.1+ provides the opt-in `_SentryTest` and `_SentryTestCI` traits for local `swift test` invocations. Swift 6.0 and `xcodebuild` package-workspace tests continue to supply these flags explicitly at the call site; see [SwiftPM SDK Tests](TEST.md#swiftpm-sdk-tests). Do not enable test traits or flags in normal package builds.

## SwiftPM Test Targets

SwiftPM test targets are separate from published SDK products. The shared `SentrySPM` scheme uses native V9/V10 Base test plans. See [SwiftPM SDK Tests](TEST.md#swiftpm-sdk-tests) for local and CI commands, V9/V10 modes, and [compiler settings and project parity](TEST.md#compiler-settings-and-project-parity).

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

## Temporary V10 Development Verification

> [!NOTE]
> This workflow applies while V9 and V10 are developed in the same branch. At the branch split, retire the temporary backend-selection checks and adapt the remaining checks for KSCrash-only V10. See [decision 40](DECISIONS.md#40-develop-v10-on-main-then-branch-off-v9) for the release plan.

These checks help ensure that V10 builds contain no legacy recorder implementation while existing V9 dependency declarations continue to work. Run the commands below from the repository root.

### SwiftPM V10 selection

`SDK_V10=1` is the authoritative SwiftPM V10 selector: it controls compiler definitions, KSCrash dependencies, and products. Do not select V10 with compiler flags alone. Default V9 remains unchanged, including with no default traits or only `NoUIFramework` enabled.

The `V10` trait originally selected compilation independently. On Swift 6.2+, it is now only a temporary compatibility marker, declared when the environment selects V10; trait-only selection is rejected. Older SDK manifests use the environment alone. Unrelated traits keep their existing behavior. The Swift module remains `SentrySwift` in both versions; environment-selected V10 uses the `Sentry` product, while V9 uses `SentrySPM`.

`SentrySampleShared/Package.swift` uses the same environment for product and compiler settings. `make switch-v10`, `make build-testapp-v10-*`, and `make test-testapp-v10-macOS-CLI-Xcode` export `SDK_V10=1` for generation and building. The generator rewrites `SentrySPM` references to `Sentry`, retains the compatibility trait, and sets the separate app-target compiler definitions. Direct generator or Xcode invocations must also receive `SDK_V10=1`.

At the V9 branch split, remove the temporary environment selector and compatibility trait. Released V10 must not require consumers to enable either.

### 1. Test the verification scripts

Run their regression tests before using the verifiers on your checkout:

```bash
./scripts/test-v10-compiler-log.sh
./scripts/test-v10-empty-objects.sh
./scripts/test-v10-sentryobjc-slice-inventory.sh
./scripts/test-v10-development-selection.sh
```

The development-selection test exercises the real Make recipes and YAML patchers with stubbed Xcode commands; it does not build apps or close Xcode. It verifies environment propagation, source product names, and app compiler definitions. Run `./scripts/test-spm-crash-backend-selection.swift` separately for real consumer builds.

### 2. Check source ownership

Check that V9 recorder sources and headers stay separate from V10, shared compatibility interfaces remain available, and the required build and test coverage is configured:

```bash
./scripts/verify-v10-sentrycrash-source-contract.swift
```

### 3. Check a V10 build

Create a fresh V10 build and save its full, verbose build log without filtering or summarizing it. Once the build has completed successfully, run:

```bash
./scripts/verify-v10-sentrycrash-objects.sh \
  --build-path /path/to/build-output \
  --build-log /path/to/raw-build.log
```

Choose `--build-path` for the build being checked:

| Build                     | Output directory                                                                                   |
| ------------------------- | -------------------------------------------------------------------------------------------------- |
| SDK or SentryObjC archive | `DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/<scheme>/IntermediateBuildFilesPath` |
| Catalyst packaging        | `DerivedData/Build/Intermediates.noindex`                                                          |
| Debug SDK                 | `DerivedData`, including `Build/Products`                                                          |

For archives, `<scheme>` is `SentryV10` or `SentryObjC`. SentryObjC also needs `--archive-path /path/to/sdk.xcarchive`: Xcode moves single-architecture package aggregates into `Products`, leaving dangling build-directory aliases. Only those logged aggregates may relocate, and their contents must still match their accounted inputs. For a copied checkout, add `--source-root /path/to/sdk`.

Use the raw log from the same build. SDK builds retain `raw-build-output.log`; SDK XCFramework slices retain `XCFrameworkBuildPath/raw-build-output.log`; SentryObjC slices retain `<output-dir>/archive/SentryObjC/<sdk>.log`. V10 packagers audit each slice before its intermediates are replaced.

Missing, incomplete or unsupported evidence fails the audit. See the [build-log reader](../scripts/read-v10-compiler-evidence.swift) and [object checker](../scripts/verify-v10-empty-objects.swift) for source/output accounting and aggregate-content checks. Build-only audit lanes disable coverage because it emits executable helpers even for empty Swift files; unit-test coverage is unchanged. Packaged artifacts and runtime behavior still need separate checks.
