# Build Configuration

This document covers the build system and configuration details for the Sentry Cocoa SDK.

### SDK Build Configuration

- XCConfig files in `Sources/Configuration/` for SDK settings; settings should not be modified in pbxproj files

## SDK Test Configurations

SDK tests use `Debug`, or `DebugV10` for V10 Xcode project builds. SwiftPM V10 tests also use `Debug`, with `SDK_V10=1` selecting the SDK implementation. Debug builds enable testability and SDK test helpers through `DEBUG`; no test traits or separate test configurations are required. Make/CI adds the [package test xcconfig](../Tests/Configuration/SwiftPM.xcconfig) for ABI and diagnostic checks. See [SwiftPM SDK Tests](TEST.md#swiftpm-sdk-tests). Release builds exclude debug/test helpers. Do not explicitly enable `DEBUG` in production builds.

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

[assemble-xcframework.sh](../scripts/assemble-xcframework.sh) combines archives, frameworks, or static libraries. See [SentryObjC Build Process](SENTRY-OBJC-BUILD.md) for wrapper packaging.

### SPM-built SDK frameworks

Select the shipping basename with `SPM_XCFRAMEWORK_VARIANT` (or `--variant` in the [build script](../scripts/build-xcframework-variant-spm.sh)). The default is the ordinary dynamic product for the selected SDK generation. The matrix below follows the [V9 release matrix](../scripts/generate_release_matrix.sh) and the [V10 build targets](../scripts/build-xcframework-v10.sh). Names are before `.xcframework.zip`.

| Generation | Artifact                               | Linkage | Framework and import | arm64e on non-simulator slices |
| ---------- | -------------------------------------- | ------- | -------------------- | ------------------------------ |
| V9         | Sentry                                 | Static  | Sentry               | Yes                            |
| V9         | Sentry-Dynamic                         | Dynamic | Sentry               | No                             |
| V9         | Sentry-Dynamic-WithARM64e              | Dynamic | Sentry               | Yes                            |
| V9         | Sentry-WithoutUIKitOrAppKit            | Dynamic | SentryWithoutUIKit   | No                             |
| V9         | Sentry-WithoutUIKitOrAppKit-WithARM64e | Dynamic | SentryWithoutUIKit   | Yes                            |
| V10        | SentryV10                              | Static  | Sentry               | Yes                            |
| V10        | SentryV10-Dynamic                      | Dynamic | Sentry               | Yes                            |

| Platform (deployment target) | Device / desktop base architectures | Simulator architectures |
| ---------------------------- | ----------------------------------- | ----------------------- |
| iOS 15, tvOS 15              | arm64                               | arm64, x86_64           |
| macOS 12, Mac Catalyst 15    | arm64, x86_64                       | —                       |
| watchOS 9                    | arm64, arm64_32                     | arm64, x86_64           |
| visionOS 1                   | arm64                               | arm64, x86_64           |

The slice architectures above are checked against the published V9 `9.35.0` static XCFramework inventory, including x86_64 on the visionOS simulator. Deployment targets are the [configured minima](../Sources/Configuration/DeploymentTargets.xcconfig); an SDK can impose a higher minimum for an individual architecture (for example, watchOS 26 for LP64 watches with Xcode 27). Add arm64e only as indicated in the product table, including for Catalyst. Dynamic slices are mergeable except on watchOS (device and simulator). Static slices contain a static archive, not a dylib; the producer retains Objective-C categories so consumers need no new linker flags. The static bundle's App Store `MinimumOSVersion` workaround does not change the objects' deployment targets. `SentrySwiftUI` is tracked separately in [#9652](https://github.com/getsentry/sentry-cocoa/issues/9652); `SentryObjC` uses its existing separate packagers.

```bash
SDK_V10=0 make build-xcframework-spm SDKS=macosx FOR_AGENTS=true
SDK_V10=1 make build-xcframework-spm SDKS=macosx FOR_AGENTS=true
```

The producer sets `SENTRY_BUILD_XCFRAMEWORK=1` and, for the no-UI variants, selects the `NoUIFramework` package trait (Swift 6.1+) and compiles the actual `SentryWithoutUIKit` module. Consumers do not set flags or change their imports. Output is `XCFrameworkBuildPath/SPM/<generation>/<variant>.xcframework.zip`, with intermediates under `build/<variant>/`. See [input preparation](../scripts/prepare-sentry-framework-inputs.sh) for framework assembly details.

Use the same [isolated binary consumer](../scripts/test-xcframework-variant.sh) on corresponding unpacked Xcode and SwiftPM products. By default it requires all ten slices. For a partial local build, pass the exact SDK list: it checks the module name, architectures, deployment targets, linkage and mergeability, links each architecture, and runs the native macOS binary to check Objective-C category availability. For no-UI variants it also checks that a native macOS process loads neither AppKit nor SwiftUI, and that an Objective-C client without modules sees only implemented declarations and can link the public version globals. The Xcode-project no-UI header and version-export discrepancies are tracked in [#9715](https://github.com/getsentry/sentry-cocoa/issues/9715). A missing required slice or failing consumer is a release blocker, not a supported matrix exclusion.

```bash
make build-xcframework-spm SPM_XCFRAMEWORK_VARIANT=Sentry SDKS=macosx FOR_AGENTS=true
./scripts/test-xcframework-variant.sh --xcframework XCFrameworkBuildPath/SPM/v9/Sentry.xcframework --sdks macosx
```

Validate an unpacked macOS artifact locally. Neither consumer needs producer compiler settings:

```bash
for generation in v9 v10; do
  artifact=Sentry-Dynamic
  if [ "$generation" = v10 ]; then artifact=SentryV10-Dynamic; fi
  for consumer in SPM-Dynamic SPM-ObjC-Dynamic; do
    SENTRY_XCFRAMEWORK="../../XCFrameworkBuildPath/SPM/$generation/$artifact.xcframework" \
      swift run --package-path "TestApps/$consumer" --configuration release "$consumer"
  done
done
```

The Swift-only [`SPM-Dynamic`](../TestApps/SPM-Dynamic) sample checks public API, SPI, and the privacy manifest from the loaded SDK bundle. The Objective-C-only [`SPM-ObjC-Dynamic`](../TestApps/SPM-ObjC-Dynamic) sample checks ordinary Objective-C imports, public API, and version exports. Both verify dynamic loading without starting integrations or sending network requests. Without `SENTRY_XCFRAMEWORK`, both consume the existing `Sentry-Dynamic` product; use `swift run --build-system xcode --package-path "TestApps/$consumer" "$consumer"` for each sample as in the Release workflow.

The [Release workflow](../.github/workflows/release.yml) runs **advisory** macOS packaging and isolated consumer checks for the ordinary SwiftPM dynamic variants (`Sentry-Dynamic` and `SentryV10-Dynamic`). The Xcode-project release matrix builds static and no-UI variants too; SwiftPM artifacts are not published. Switching releases requires platform/API parity and mandatory packaging/consumer gates.

## Public API Generation

`make generate-public-api` runs [`update-api.sh`](../scripts/update-api.sh) with Xcode 16. It updates the existing Xcode-framework and ObjC-wrapper snapshots and adds only `sdk_api_spm.json` and `sdk_api_v10_spm.json` from the [SPM-built frameworks](#spm-built-sdk-frameworks).

The [API stability workflow](../.github/workflows/api-stability.yml) runs the same target and fails if a checked-in snapshot differs from the regenerated API.

Source-backed SentrySwiftUI extraction is deferred; its package target still uses the released binary.

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

Use `SDK_V10=1` for V10 compiler settings, KSCrash dependencies, and the `Sentry` source product. The `V10` trait has been removed; V9 defaults and unrelated traits remain unchanged. See [decision 41](DECISIONS.md#41-select-swiftpm-v10-through-the-environment-only).

| Selection      | SDK | Source product / Swift module |
| -------------- | --- | ----------------------------- |
| No `SDK_V10=1` | V9  | `SentrySPM` / `SentrySwift`   |
| `SDK_V10=1`    | V10 | `Sentry` / `Sentry`           |

For ordinary source builds, shared SDK and test code imports `SentrySwift` under `#if SWIFT_PACKAGE && !SDK_V10` and `Sentry` otherwise. The packaging-only mode above also selects `Sentry`, using explicit `SENTRY_BUILD_XCFRAMEWORK` compiler conditions for internal imports. Do not use `canImport` to select a version or module name: cached modules can survive mode switches.

`make switch-v10`, `make build-testapp-v10-*`, and `make test-testapp-v10-macOS-CLI-Xcode` export the environment for generation and building. The generator selects the source product and sets app-target compiler definitions. Direct generator or Xcode invocations also need `SDK_V10=1`.

### 1. Test the verification scripts

Run their regression tests before using the verifiers on your checkout:

```bash
./scripts/test-v10-compiler-log.sh
./scripts/test-v10-empty-objects.sh
./scripts/test-v10-sentryobjc-slice-inventory.sh
./scripts/test-v10-development-selection.sh
```

The development-selection test exercises the real Make recipes and YAML patchers with stubbed Xcode commands; it does not build apps or close Xcode. It verifies environment propagation, source product names, and app compiler definitions.

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
