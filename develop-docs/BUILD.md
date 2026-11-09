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

`assemble-xcframework.sh` accepts per-SDK XCArchives (`--archive-template` and `--scheme`), standalone frameworks (`--framework-template`), or static libraries (`--library-template` and `--headers`). Each template substitutes `SDK_NAME` for each entry in `--sdks`. Standalone slices can use `--output` without a scheme. Assembly replaces an existing output only after checking the slice inputs. Dynamic callers pass `--require-debug-symbols` to fail if any framework slice lacks a dSYM; static artifacts do not require dSYMs. See [SentryObjC Build Process](SENTRY-OBJC-BUILD.md) for the SwiftPM slice pipeline and its extra static-library validation.

### Source-built SDK frameworks

The source archive → dynamic framework → XCFramework scripts support packaging both SentryObjC and the main SDK from SwiftPM sources. `build-static-library.sh` requires `--sdk`, `--output-dir`, `--package-path`, `--configuration`, `--scheme`, and `--architecture-target`. The scheme selects the product/output name; the architecture target selects the compiled target whose architectures must be present. V9 uses scheme `SentrySPM`; V10 uses `Sentry`. Both currently compile target `SentrySwift`. SentryObjC callers explicitly pass scheme `SentryObjC` and architecture target `SentryObjCCompat`.

For the main Swift SDK, `prepare-sentry-framework-inputs.sh` requires `--swift-archive`, `--headers`, `--output-dir`, and `--framework-name`. The framework name must match the compiled Swift module. Use the same `SDK_V10` setting as the archive. This Sentry-specific step prepares `Headers/`, `Modules/`, and `Resources/` in a separate staging directory without modifying the input headers or archive. It copies public headers verbatim, creates the umbrella header and module map, folds `SentryHeaders` references into the framework's underlying Clang module, and includes the generated Objective-C header, V10 configuration when enabled, privacy manifest, and resource bundles. Interface rewriting handles both legacy `SentryHeaders.Type` and Swift 6.4's `SentryHeaders::Type` qualification without renaming compiled Swift symbols. Public and private Swift interfaces are retained; package interfaces and producer-specific serialized modules are not distributed. Public headers retain framework-qualified imports for `Sentry` and `SentryWithoutUIKit`; fallback imports resolve sibling headers without extra consumer search paths. The separate SwiftPM V10 configuration header keeps its conditional dependency-based lookup and is copied and imported first by the generated umbrella only for V10.

`build-dynamic-framework.sh` requires `--sdk`, `--static-lib`, `--headers`, `--output-dir`, `--version`, and `--framework-name`; it does not infer a version or framework name. Optional `--modules` and `--resources` directories supply already-prepared contents, copied verbatim into the platform-specific framework layout. A supplied `module.modulemap` is preserved; otherwise the builder generates a headers-only module map using `<framework-name>.h`. The builder links the binary and generates its dSYM, without performing Sentry-specific header or interface transformations. SentryObjC callers continue passing their original public headers and do not need the preparation step.

The main SDK pipeline is `build-static-library.sh` → `prepare-sentry-framework-inputs.sh` → `build-dynamic-framework.sh` → `assemble-xcframework.sh`. One XCFramework/binary target supports `import SentrySwift` without a companion headers artifact. V10 will use `import Sentry` after the upstream module rename lands.

For example, to package a V9 iOS device slice:

```bash
export SDK_V10=0
source scripts/ci-utils.sh
source scripts/tools.sh
version="$(read_xcconfig_value_or_exit --key MARKETING_VERSION --file Sources/Configuration/Versioning.xcconfig)"
./scripts/build-static-library.sh \
  --sdk iphoneos \
  --scheme SentrySPM \
  --architecture-target SentrySwift \
  --package-path "$(pwd)" \
  --configuration Release \
  --output-dir XCFrameworkBuildPath
prepared=XCFrameworkBuildPath/prepared/SentrySwift/iphoneos
./scripts/prepare-sentry-framework-inputs.sh \
  --swift-archive XCFrameworkBuildPath/archive/SentrySPM/iphoneos.xcarchive \
  --headers Sources/Sentry/Public \
  --framework-name SentrySwift \
  --output-dir "$prepared"
./scripts/build-dynamic-framework.sh \
  --sdk iphoneos \
  --framework-name SentrySwift \
  --version "$version" \
  --output-dir XCFrameworkBuildPath \
  --static-lib XCFrameworkBuildPath/lib/SentrySPM/iphoneos/libSentrySPM-Debug.a \
  --headers "$prepared/Headers" \
  --modules "$prepared/Modules" \
  --resources "$prepared/Resources"
./scripts/assemble-xcframework.sh \
  --sdks iphoneos \
  --framework-template "$(pwd)/XCFrameworkBuildPath/framework/SentrySwift/SDK_NAME/SentrySwift.framework" \
  --output "$(pwd)/SentrySwift.xcframework" \
  --require-debug-symbols
```

`compress-xcframework.sh` signs when requested and creates the ZIP. `ci-diagnostics.sh` reports the active Swift compiler via `xcrun swift --version` alongside Xcode and SDK details.

Run script argument, input preparation, dSYM, and compression regressions with `python3 scripts/test-xcframework-scripts.py -v`. Run architecture regression tests with `./scripts/test-sentryobjc-archive-architectures.sh`. On macOS with Xcode selected, `python3 scripts/test-spm-framework-packaging.py -v` archives a dependency-free fixture, prepares its framework inputs, assembles one XCFramework, deletes the producer sources and intermediates, and builds/runs a clean SwiftPM consumer. It checks public API, SPI, Objective-C header import, and resource lookup. It also compiles unmodified SDK public headers in source and framework layouts for V9/V10, Objective-C/Objective-C++, and modules enabled/disabled on macOS and iOS, including the existing `Sentry` framework's strict quoted-include warning.

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

### 1. Test the verification scripts

Run their regression tests before using the verifiers on your checkout:

```bash
./scripts/test-v10-compiler-log.sh
./scripts/test-v10-empty-objects.sh
./scripts/test-v10-sentryobjc-slice-inventory.sh
```

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
