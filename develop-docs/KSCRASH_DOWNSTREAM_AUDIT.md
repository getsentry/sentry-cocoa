# KSCrash Downstream SDK Audit

Audit of downstream SDK use of private, SPI, and V10-removed `sentry-cocoa` APIs for [#8738](https://github.com/getsentry/sentry-cocoa/issues/8738). Read it with the [SentryCrash V10 Migration Ledger](SENTRYCRASH_V10_MIGRATION_LEDGER.md); `SCV10-*` IDs refer to its rows.

> [!NOTE]
> Static audit from 2026-09-17 against `sentry-cocoa` `main` after 9.29.0 and the default branch of each downstream repository. Only .NET was built and run against a V10 artifact, see [.NET Validation Run](#net-validation-run). Findings marked _inferred_ come from reading code only.

## Summary

- No downstream SDK other than Kotlin Multiplatform depends on `SentryCrash` types. `SCV10-037` holds for every other SDK.
- `SentryKSCrashQuery` has no downstream consumers. Downstream SDKs read last-run state through `crashedLastRun` or `lastRunStatus`.
- The largest breaks are not caused by KSCrash:
  - `PrivateSentrySDKOnly` and `SentryObjCPrivateSDKOnly` no longer exist in 9.29.0 ([#9030](https://github.com/getsentry/sentry-cocoa/pull/9030)).
  - V10 removes `crashedLastRun`, `sendDefaultPii`, `enableLogs`, `enableAppHangTracking`, and `pauseAppHangTracking` / `resumeAppHangTracking`.
  - V10 `SentrySDK` is a Swift `enum` without Objective-C visibility, see [`SentrySDK.swift`](../Sources/Swift/Helper/SentrySDK.swift).
- .NET is the only SDK with a KSCrash-specific crash-handling regression. It is tracked by [#8797](https://github.com/getsentry/sentry-cocoa/issues/8797) (`SCV10-007`, `SCV10-033`).
- .NET, Unity, Godot, and Unreal consume `SentryObjC`, which `scripts/build-xcframework-sentryobjc.sh --v10` now builds locally for steps 2 and 3 of #8738. A released or CI-built V10 `SentryObjC` artifact is still missing for step 5. See [Cocoa-Side Gaps](#cocoa-side-gaps).

## Risk Overview

| SDK                  | Pinned Cocoa                                                                            | Consumption                                                    | V10 breaks                                                                | KSCrash behavior risk                                                                                                |
| -------------------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Kotlin Multiplatform | 8.58.2; 9.28.0 on the `codex/sentry-cocoa-v9-migration` branch                          | CocoaPods plus vendored private headers; spm4kmp on the branch | SentryCrash stack cursor, `crashReporter`, `sentrycrash_setMonitoring`    | High: unhandled-exception flow is built on SentryCrash internals on both branches                                    |
| .NET                 | 9.29.0                                                                                  | Source-built `SentryObjC-Dynamic.xcframework`                  | `crashedLastRun`, `sendDefaultPii`, `enableAppHangTracking`               | High, verified: duplicate `SIGABRT` events and a spurious fatal `EXC_BAD_ACCESS` per caught `NullReferenceException` |
| Flutter              | 8.58.4                                                                                  | CocoaPods `Sentry/HybridSDK` and SPM                           | `sendDefaultPii`, app-hang APIs, `SentryCrashIntegration` test assertion  | Low                                                                                                                  |
| React Native         | 9.29.0                                                                                  | Prebuilt static `Sentry.xcframework`                           | Every Objective-C `[SentrySDK …]` call, `crashedLastRun`, `enableLogs`    | Low                                                                                                                  |
| Unity                | 9.29.0                                                                                  | Source-built `SentryObjC` framework and dylib                  | None at build time                                                        | Medium: app-hang coverage lost, C++ throw-site stacks lost                                                           |
| Unreal               | 9.29.0                                                                                  | Released `SentryObjC-Dynamic.xcframework`                      | `crashedLastRun`, `sendDefaultPii`, `enableLogs`, `enableAppHangTracking` | Medium: own iOS signal handlers chain into the crash reporter                                                        |
| Godot                | 9.29.0                                                                                  | Released `SentryObjC-Dynamic.xcframework`                      | `sendDefaultPii`, `enableLogs`, `enableAppHangTracking`                   | Low                                                                                                                  |
| Capacitor            | `exact: "9.28.0"` SPM, pinned by getsentry/sentry-capacitor#1404 after the 9.29.0 break | SPM source                                                     | `sendDefaultPii`, `enableAppHangTracking`                                 | Low                                                                                                                  |
| Cordova              | 8.56.2                                                                                  | Carthage                                                       | `integrations` array with `"SentryCrashIntegration"`                      | Low                                                                                                                  |
| Xamarin              | None                                                                                    | `Sentry` NuGet only                                            | None                                                                      | None: exposure is in .NET                                                                                            |

## Cross-Cutting Findings

### V10-Removed Public API Used Downstream

| API                                              | Used by                                           | V10 replacement                                               |
| ------------------------------------------------ | ------------------------------------------------- | ------------------------------------------------------------- |
| `crashedLastRun`                                 | React Native, .NET, Unreal                        | `lastRunStatus`; consumers must map `unknown`                 |
| `sendDefaultPii` property or dictionary key      | All except Cordova, Kotlin Multiplatform, Xamarin | `dataCollection`; the dictionary key is silently ignored      |
| `enableAppHangTracking`                          | Flutter, .NET, Unity, Unreal, Godot, Capacitor    | None; legacy app hangs are removed                            |
| `pauseAppHangTracking` / `resumeAppHangTracking` | React Native, Flutter                             | None                                                          |
| `enableLogs` property or dictionary key          | React Native, Unity, Unreal, Godot                | None; logs are always enabled                                 |
| Objective-C `[SentrySDK …]`                      | React Native                                      | Swift bridge or `SentryObjCSDK`                               |
| `"SentryCrashIntegration"` name string           | Flutter integration test, Cordova                 | `enableCrashHandler`; V10 installs `SentryKSCrashIntegration` |

- Unity disables its C# ANR watchdog when `enableAppHangTracking` is set, so V10 silently removes app-hang coverage on iOS and macOS. Unity skips its app-hang tests for the Cocoa backend, so CI does not catch it.
- Dictionary-based initialization in React Native and Unity compiles unchanged while `sendDefaultPii` and `enableLogs` stop applying.

### Ledger Gaps With Downstream Impact

| Ledger row               | Downstream impact                                                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `SCV10-007`, `SCV10-033` | .NET; Mono on macOS under Unity is unverified                                                                                         |
| `SCV10-015`              | Hybrid scope data in native crash reports; Unity crash tests assert user, tags, and environment                                       |
| `SCV10-029`, `SCV10-030` | Unity `__sentry_cxa_throw` handoff is a pure forward; throw-site stacks need `enableUnhandledCPPExceptionsV2`, which Unity never sets |
| `SCV10-032`              | React Native, Flutter, and Unity call `close`; KSCrash keeps recording afterwards                                                     |
| `SCV10-027`, `SCV10-039` | Trace persistence and replay crash recovery for React Native and Flutter                                                              |
| `SCV10-008`              | Unreal takes crash-time screenshots from its own signal handlers and may duplicate the native capture                                 |

## Per-SDK Findings

### Kotlin Multiplatform

- The `codex/sentry-cocoa-v9-migration` branch (checked 2026-09-18, head `9bcd1dc`) moves to 9.28.0 through spm4kmp and adds a Swift shim, `src/swift/sentryCocoa/SentryKMPInternal.swift`, that forwards `setSdkName`, `storeEnvelope`, and debug-image lookup to `SentrySDK.internal`. That removes the `PrivateSentrySDKOnly` and CocoaPods breaks but none of the V10 ones below
- Both branches vendor private headers under `src/nativeInterop/cinterop/SentryInternal/`, so missing selectors fail at runtime instead of at build time
- The unhandled Kotlin exception flow in `nsexception/SentryUnhandledExceptions.kt` calls `SentryDependencyContainer.crashReporter.uncaughtExceptionHandler`, which is absent in V10 (`SCV10-037`, `SCV10-040`)
- Every Kotlin exception, handled or not, builds its stack trace with `sentrycrashsc_initWithBacktrace` and `retrieveStacktraceFromCursor:`. V10 excludes `SentryCrashStackCursor_Backtrace.c`, and `retrieveStacktraceFromCursor:` is inside `#if !SDK_V10` in [`SentryStacktraceBuilder.m`](../Sources/Sentry/SentryStacktraceBuilder.m). The migration branch keeps this path in a vendored `NSExceptionKt_SentryStacktraceFromNSException` helper
- `SentryApple.kt` disables the C++ exception monitor. `main` sets `crashReporter.monitoring`, which has no setter in 9.x; the migration branch replaces it with the C API `sentrycrash_setMonitoring(sentrycrashcm_getActiveMonitors() & ~CPPException)` from `SentryCrashC.h`, which is compiled out in V10. KSCrash has no equivalent toggle after install (`SCV10-030`)
- `main` also uses `SentryClient.prepareEvent`, `getDebugImagesForThreads:`, and `SentrySDKInternal.storeEnvelope`; the migration branch replaces them with `SentrySDK.internal` calls
- KSCrash has equivalents (`uncaughtExceptionHandler`, `kssc_initWithBacktrace`, `KSCrashConfiguration.monitors`), but importing them directly is not viable: a second KSCrash copy has its own uninstalled `KSCrash.shared`, `monitors` is read once inside `SentryKSCrash.Installer`, and V10 `buildStackTraceFromAddresses:` needs no cursor
- Needs from Cocoa: an SPI to report a fatal `NSException` through the active crash backend on all platforms, an SPI to build a stack trace from return addresses, and a decision on the C++ monitor toggle. `SentryKMPInternal.swift` on the migration branch is the natural consumer of all three, which would let KMP drop the vendored headers entirely

### .NET

- Binds only `SentryObjC.h`; no `PrivateSentrySDKOnly`, private headers, or integration-name strings
- 3 of 253 bound selectors are used and absent in V10: `crashedLastRun`, `sendDefaultPii`, `enableAppHangTracking`. Without regenerated bindings they fail at runtime with an unrecognized selector
- `scripts/sentry-cocoa.xcconfig` injects `SENTRY_CRASH_MANAGED_RUNTIME=1`. Every file that honors it is excluded from V10
- Unhandled managed exception: `ignoreNextSignal(SIGABRT)` is a no-op in V10, so KSCrash records the abort and a duplicate native event is sent on the next launch. Verified, see below
- `NullReferenceException`: Mono still converts the `EXC_BAD_ACCESS` into a catchable managed exception, but KSCrash records a fatal report first, so every caught null dereference sends a spurious fatal `EXC_BAD_ACCESS` event on the next launch. Verified, see below. `DivideByZeroException` (`EXC_ARITHMETIC`) follows the same path and was not run
- Acceptance tests for #8797: the four crash cases in `integration-test/ios.Tests.ps1`

#### .NET Validation Run

Run on 2026-09-18 against the .NET checkout at 9.28.0 with the iOS integration test app from `integration-test/net9-maui` on an iOS 26.3 simulator, Mono, Release, against a V10 `SentryObjC-Dynamic.xcframework` built from this branch with `scripts/build-xcframework-sentryobjc.sh --v10`. The Pester harness was replaced by a local envelope sink because `pwsh` and `sharpie` were not installed; the bindings were edited by hand to what a V10 sharpie run produces (`crashedLastRun` replaced by `lastRunStatus`, seven V10-removed option selectors dropped). Each scenario launches once to crash and once more to deliver.

| Scenario                 | V9 expectation                               | V10 result                                                                                        | Status |
| ------------------------ | -------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------ |
| `Managed`                | 1 `System.ApplicationException`, no signal   | `System.ApplicationException` plus a fatal `SIGABRT` native event                                 | Fails  |
| `OnActivated`            | 1 `System.ApplicationException`, no signal   | `System.ApplicationException` plus a fatal `SIGABRT` native event                                 | Fails  |
| `Native`                 | 1 `EXC_BAD_ACCESS`, no managed exception     | 1 `EXC_BAD_ACCESS`                                                                                | Passes |
| `NullReferenceException` | 1 `System.NullReferenceException`, no signal | `System.NullReferenceException` plus a fatal `EXC_BAD_ACCESS` native event; the app did not crash | Fails  |

- The build itself works: `SDK_V10=1` produces a linkable dynamic framework with KSCrash embedded, and the C# code compiles once the bindings match the V10 headers
- The duplicate `SIGABRT` confirms `SCV10-007`. The spurious `EXC_BAD_ACCESS` is the Mach-monitor gap in `SCV10-033`: KSCrash sits above Mono and has no way to exclude `EXC_BAD_ACCESS` and `EXC_ARITHMETIC`
- The native events carry no tags, and the installer logs `Dropping 'context'` and `Dropping 'traceContext'` at start, which is `SCV10-015`
- `SentrySDK.close` followed by `exit(0)` on the delivery launch worked; `SCV10-032` was not exercised further
- Mac Catalyst and CoreCLR have no runtime crash coverage downstream

### Flutter

- Blocked by the 8.x to 9.29 migration, not by KSCrash: about 25 `PrivateSentrySDKOnly` call sites, `import Sentry._Hybrid`, `sentry_formatHexAddressUInt64`, `options.integrations`, and replay helpers that moved to `SentrySessionReplayHybridSDK`
- FFI profiling looks up `PrivateSentrySDKOnly` and `Sentry.SentryId` at runtime. The failure is swallowed in production, so profiling silently stops. `SentrySDK.internal` is a Swift struct and unreachable from FFI; the FFI path must target `SentryObjCSDK.internal.profiling` or the method channel
- The generated `SentryCrashWrapper` binding is unused ffigen output
- No hybrid API exposes installed integration names, which Flutter reads today
- With V10 SPM, the `Sentry` product maps to the Swift module `SentrySwift`, so `import Sentry` does not resolve

### React Native

- Already uses `SentrySDK.internal` through `RNSentryInternal.swift`. All members exist in V10, and `ignoreNextSignal` is unused
- Objective-C callers in `SentrySDKWrapper.m`, `RNSentryStart.m`, and the sample initializer cannot see V10 `SentrySDK`
- Still reaches SPI classes from Objective-C: `SentryDependencyContainer` (`framesTracker`, `binaryImageCache`, `debugImageProvider`, `dateProvider`), `SentryFramesTracker`, `SentrySDKLog`, and a private `SentryUser` category. All exist in V10. Whether they are a supported V10 contract is undecided
- Forces a prebuilt static xcframework with hardcoded slice names and `-force_load` of `Sentry.framework/Sentry` only, so a V10 static artifact must embed KSCrash objects

### Unity

- Already uses `SentryObjCSDK.internal` and `lastRunStatus`. No build breaks
- Behavior changes: app-hang coverage, `sendDefaultPii`, `enableLogs`, the `__sentry_cxa_*` handoff, and `close`
- The `dlsym` handoff crosses images (dynamic `SentryObjC` plus a weak wrapper in `UnityFramework`). Cocoa tests cover only the single-image case

### Unreal, Godot, Capacitor, Cordova

- Unreal: already on `SentryObjCSDK.internal`. Uses four V10-removed APIs. Its iOS signal handlers in `IOSSentrySubsystem.cpp` take a screenshot, restore the previous handlers, and re-raise. KSCrash chaining and ordering are unverified
- Godot: already on 9.29.0 and `SentryObjCSDK.internal` since getsentry/sentry-godot#969 and #970 (2026-09-18). Uses three V10-removed options
- Capacitor: the `from: "9.24.0"` range resolved to 9.29.0 and broke user builds (getsentry/sentry-capacitor#1403). #1404 pins `exact: "9.28.0"`, and #1407 tracks the `SentrySDK.internal` migration, which has no PR yet. All nine `PrivateSentrySDKOnly` call sites have direct replacements
- Cordova: `PrivateSentrySDKOnly`, `SentryOptionsInternal.h`, and the `integrations` array are all gone on `main`

## Cocoa-Side Gaps

### Verified Regressions

1. Managed-runtime crash handling, [#8797](https://github.com/getsentry/sentry-cocoa/issues/8797), `SCV10-007` and `SCV10-033`. The .NET run shows a duplicate `SIGABRT` event per unhandled managed exception and a spurious fatal `EXC_BAD_ACCESS` event per caught `NullReferenceException`. #8797 covers handler ordering, `ignoreNextSignal`, and duplicate reports, but not the Mach-exception exclusion that `SENTRY_CRASH_MANAGED_RUNTIME` provided in V9, which dropped `EXC_BAD_ACCESS` and `EXC_ARITHMETIC` from the Mach monitor
2. Crash-time scope, `SCV10-015`, #8276 and #8756. V10 native crash events carry no tags, and the installer drops nested `context` and `traceContext` values at start. Hybrid SDKs sync their scope through nested values, so every hybrid crash event is affected. Seen in the .NET run

### Packaging

3. No released or CI-built V10 `SentryObjC` artifact. `scripts/build-xcframework-sentryobjc.sh --v10` builds one locally, see [SentryObjC build](SENTRY-OBJC-BUILD.md#v10-builds). `scripts/verify-v10-sentrycrash-framework.sh` audits only `Sentry.framework`. Affects .NET, Unity, Godot, and Unreal
4. Shipped headers keep `#if SDK_V10` gates. `SentryObjC` has them in 13 public headers, which the local `--v10` build resolves with `unifdef`. `Sentry.xcframework` from `scripts/build-xcframework-v10.sh` ships them unresolved in [`SentryDefines.h`](../Sources/Sentry/Public/SentryDefines.h) and [`SentryRequest.h`](../Sources/Sentry/Public/SentryRequest.h). Whether a consumer that does not define `SDK_V10` still compiles against the generated Swift header is unverified
5. Whether a V10 static `Sentry.xcframework` embeds the KSCrash objects and keeps the slice names React Native hardcodes is unverified
6. The V10 SPM product `Sentry` maps to the Swift module `SentrySwift` ([`Package.swift`](../Package.swift)), so `import Sentry` does not resolve for source consumers such as Flutter and Capacitor

### Missing SPI

7. Kotlin Multiplatform: report a fatal `NSException` through the active crash backend on all platforms, build a `SentryStacktrace` from return addresses, and a start-time option to exclude the C++ exception monitor (`SCV10-030` has no toggle after install)
8. Flutter: installed integration names, previously read from `options.integrations`

### Decisions

9. Whether the `@_spi(Private) @objc` classes reached from Objective-C by React Native and Flutter (`SentryDependencyContainer`, `SentryFramesTracker`, `SentryBinaryImageCache`, `SentryDebugImageProvider`, `SentrySDKLog`) are a supported V10 contract, or get `SentrySDK.internal` equivalents
10. `SentrySDK` is a Swift `enum` without Objective-C visibility in V10. This follows the `SentryObjC` design, but React Native's Objective-C bridge depends on it and the change is not called out for hybrid maintainers
11. No consolidated list of removed options and APIs for hybrid maintainers beyond [`CHANGELOG_V10.md`](../CHANGELOG_V10.md): `crashedLastRun`, `sendDefaultPii`, `enableLogs`, `enableAppHangTracking`, `pauseAppHangTracking` / `resumeAppHangTracking`, `enableSigtermReporting`, and that their dictionary keys are silently ignored
12. No cross-image test of the `__sentry_cxa_throw` handoff, which is how Unity uses it (`SCV10-029`)

## Recommended Follow-Up Issues

### sentry-cocoa

- #8797: add the four .NET crash cases from `integration-test/ios.Tests.ps1` as acceptance tests and add Mach `EXC_BAD_ACCESS` and `EXC_ARITHMETIC` exclusion to the scope (gap 1)
- Prioritize `SCV10-015` before any hybrid SDK ships on V10, and add a hybrid scope-sync case to its acceptance test (gap 2)
- Add a CI job for the V10 `SentryObjC` xcframework, extend `verify-v10-sentrycrash-framework.sh` to `SentryObjC.framework`, and resolve `SDK_V10` header gates in both framework packaging paths (gaps 3 and 4)
- Build and verify a static V10 `Sentry.xcframework` with the slice layout React Native expects (gap 5)
- Decide the V10 SPM module name (gap 6)
- Add the Kotlin Multiplatform SPI and a ledger row for the flow (gap 7)
- Add an `internal` API for installed integration names (gap 8)
- Decide the React Native SPI contract and document the `SentrySDK` Objective-C change (gaps 9 and 10)
- Publish the removed-API list for hybrid maintainers (gap 11)
- Add cross-image `__sentry_cxa_throw` coverage (gap 12)

### Downstream

- Capacitor: land getsentry/sentry-capacitor#1407 so the 9.28.0 pin from #1404 can be lifted. Unrelated to V10
- Flutter, Cordova: migrate from 8.x to 9.29 and `SentrySDK.internal` before any V10 work
- Kotlin Multiplatform: land `codex/sentry-cocoa-v9-migration`, then move the exception hook, stack-trace helper, and C++ monitor toggle onto the new Cocoa SPI so the vendored `SentryInternal` headers can go
- React Native, .NET, Unreal: migrate `crashedLastRun` to `lastRunStatus`, which already exists in 9.x
- All: replace `sendDefaultPii` with `dataCollection` and remove `enableLogs` and app-hang options under V10
- React Native: route Objective-C `[SentrySDK …]` calls through Swift or `SentryObjCSDK`, and move off direct `SentryDependencyContainer` access where `SentrySDK.internal` has an equivalent
- Flutter: move FFI profiling to `SentryObjCSDK.internal.profiling` and make the integration-name assertion backend-agnostic
- Unity: keep the C# ANR watchdog under V10 and decide on `enableUnhandledCPPExceptionsV2`
- Unreal: verify or remove the iOS signal-handler screenshot hook in favor of `SCV10-008`
- .NET: add a V10 build mode (`SDK_V10=1`, sharpie with `-DSDK_V10=1`, no managed-runtime xcconfig)

## Downstream Validation Commands

Run these against a V10 artifact once one exists for the consumption mode.

| SDK                  | Override                                                                                                                                                                | Tests                                                                                                                    |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| React Native         | Place a static V10 xcframework at `$SENTRY_XCFRAMEWORK_CACHE_DIR/<version>/Sentry.xcframework` (untested)                                                               | `native-tests.yml` (`RNSentryCocoaTester`), `e2e-v2.yml` including `maestro/crash.yml`                                   |
| Flutter              | Local SPM path or a `binaryTarget` wrapper after the 9.x migration                                                                                                      | `flutter_test.yml` integration tests for iOS and macOS, `Runner` native tests                                            |
| .NET                 | `--v10` in the `build-xcframework-sentryobjc.sh` call in `scripts/build-sentry-cocoa.sh`, drop the managed-runtime xcconfig, regenerate bindings with `-DSDK_V10=1`     | `device-tests-ios.yml`, `integration-test/ios.Tests.ps1` crash cases                                                     |
| Unity                | `--v10` in the `build-xcframework-sentryobjc.sh` calls in `scripts/build-cocoa-sdk.ps1`                                                                                 | `test-run-ios.yml` and `test-run-desktop.yml` with `SENTRY_TEST_BACKEND=cocoa`, `Integration.Tests.ps1` crash assertions |
| Kotlin Multiplatform | On the migration branch, point the spm4kmp package at a local V10 checkout with `SDK_V10=1`; the vendored `SentryInternal` headers still reference compiled-out symbols | `kotlin-multiplatform.yml` (`scripts/build-apple.sh`)                                                                    |
| Unreal, Godot        | Replace the downloaded `SentryObjC-Dynamic.xcframework` with the output of `scripts/build-xcframework-sentryobjc.sh --v10 --variant dynamic`                            | Unreal `ci.yml` iOS and macOS integration tests, Godot `test_integration.yml`                                            |
| Capacitor            | Local SPM path override with `SDK_V10=1`                                                                                                                                | `sample-build.yml`, `buildandtest.yml`                                                                                   |
