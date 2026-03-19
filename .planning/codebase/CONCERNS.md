# Codebase Concerns

**Analysis Date:** 2026-03-19

## Tech Debt

### SentryCrash Monolithic Tools Directory

**Issue:** The `Sources/SentryCrash/Recording/Tools/` directory contains 56% of all SentryCrash code (11,872 lines across 20+ files) with no organizational structure. Files mix CPU-specific register handling, JSON encoding, ObjC runtime introspection, and kernel utilities without clear boundaries.

**Files:** `Sources/SentryCrash/Recording/Tools/*.c`

**Impact:** Makes code navigation difficult, increases cognitive load for contributors, complicates testing strategy, and makes it hard to identify which utilities are load-bearing vs. legacy.

**Fix approach:** Reorganize into logical sub-modules:

- `CPU/` — CPU architecture-specific code
- `StackWalking/` — Stack cursor variants
- `Kernel/` — Mach/system interfaces
- `Introspection/` — ObjC runtime utilities
- `Serialization/` — JSON codec
- `System/` — File, memory, and syscall utilities

### Deprecated 32-bit Platform Code

**Issue:** Dead code for 32-bit ARM (`SentryCrashCPU_arm.c`) and 32-bit x86 (`SentryCrashCPU_x86_32.c`) remains in codebase despite unsupported platforms (iOS 11+ and macOS 10.15+ dropped 32-bit support in 2019).

**Files:** `Sources/SentryCrash/Recording/Tools/SentryCrashCPU_arm.c`, `Sources/SentryCrash/Recording/Tools/SentryCrashCPU_x86_32.c`

**Impact:** Maintenance burden; increases codebase size and testing matrix without benefit.

**Fix approach:** Remove both files in a future major version (v10+). Document removal in changelog to help users still on legacy branches.

### Global State in SentryCrash

**Issue:** Multiple subsystems communicate through global variables rather than explicit dependency injection:

- `g_installed`, `g_monitoring` in `Sources/SentryCrash/Recording/SentryCrashC.c`
- `g_allMachThreads`, `g_allPThreads` in `Sources/SentryCrash/Recording/SentryCrashCachedData.c`
- `g_isHandlingCrash` in `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor.c`
- Function pointer callbacks: `g_saveScreenShot`, `g_saveViewHierarchy`, `g_saveTransaction`

**Files:** `Sources/SentryCrash/Recording/SentryCrashC.c`, `Sources/SentryCrash/Recording/SentryCrashCachedData.c`, `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor.c`

**Impact:** Makes code harder to test in isolation, increases implicit coupling between modules, and complicates thread safety analysis (some globals are atomic, others are not consistently protected).

**Fix approach:** Replace with explicit dependency injection where feasible; understand that some globals are necessary due to signal-handler constraints (async-signal-safe functions cannot allocate memory or call pthread functions). Document which globals are unavoidable.

### Tight SDK ↔ SentryCrash Coupling

**Issue:** 34 non-SentryCrash files import 17+ SentryCrash headers directly. SentryCrash files import back into SDK (`SentryAsyncSafeLog.h`, `SentryInternalCDefines.h`, `SentrySessionReplaySyncC.h`), creating bidirectional dependency.

**Files:** `Sources/Sentry/SentryClient.m`, `Sources/Sentry/SentrySDKInternal.m`, `Sources/Sentry/SentryCrashReportConverter.m`, plus ~31 more; reciprocal imports in `Sources/SentryCrash/Recording/Monitors/*.c`

**Impact:** Changes to SentryCrash internal headers can accidentally break SDK; harder to reason about which SDK features depend on SentryCrash; complicates potential future refactoring (e.g., optional crash reporting).

**Fix approach:** Create a `SentryCrashFacade` — single public interface that SDK uses to interact with crash system. Scope-sync, session-replay callbacks, and transaction recording should be injected into SentryCrash via callback pointers, not imported directly.

## Known Bugs

### NSDictionary Introspection Broken

**Issue:** `sentrycrashobjc_dictionaryFirstEntry()` in `Sources/SentryCrash/Recording/Tools/SentryCrashObjC.c:1816` marked as "TODO: This is broken." Function attempts to read internal `__CFBasicHash` structure, but pointer arithmetic is incorrect or unsafe.

**Symptom:** Dictionary contents in crash reports may be missing or incorrect; potential memory access violations during crash writing.

**Files:** `Sources/SentryCrash/Recording/Tools/SentryCrashObjC.c:1816-1850`

**Trigger:** Crash occurs while app holds references to NSDictionary objects.

**Workaround:** None. Dictionary values in crash reports are incomplete.

**Related GitHub issue:** [#7298](https://github.com/getsentry/sentry-cocoa/issues/7298) — "Application Specific Information" contains random memory contents (PII risk)

### Mach Exception Handler Freeze Workaround Unclear

**Issue:** In `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_MachException.c:343`, a freeze workaround was added to suppress secondary thread resumption. Comment states: "TODO: This was put here to avoid a freeze. Does secondary thread ever fire?"

**Symptom:** Risk of Mach exception handling hanging on primary thread.

**Files:** `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_MachException.c:343`

**Cause:** Unknown. Original issue not documented.

**Recommendation:** Investigate and either document the freeze scenario or remove the workaround if no longer necessary.

**Related GitHub issue:** [#1589](https://github.com/getsentry/sentry-cocoa/issues/1589) — `handleExceptions()` crashes on macOS

### Unimplemented Report Introspection Cases

**Issue:** `Sources/SentryCrash/Recording/SentryCrashReport.c:653` has TODO for unimplemented NSDictionary and NSException introspection cases in crash report generation.

**Files:** `Sources/SentryCrash/Recording/SentryCrashReport.c:651-657`

**Impact:** Crash reports for apps holding NSDictionary or NSException objects lack detailed introspection; only generic fallback data is included.

**Fix approach:** Implement proper ObjC introspection for both types (requires safe memory reading during signal handler context).

### CPU Architecture Detection Returns NULL

**Issue:** `sentrycrashcpu_currentArch()` in `Sources/SentryCrash/Recording/Tools/SentryCrashCPU.c:42` permanently returns NULL due to App Store restrictions on `NXGetLocalArchInfo()`.

**Files:** `Sources/SentryCrash/Recording/Tools/SentryCrashCPU.c:41-42`

**Impact:** `cpu_type` and `cpu_subtype` fields missing from crash reports; harder to identify architecture-specific bugs.

**Workaround:** Infer architecture from `__SIZEOF_POINTER__` or other compile-time constants, but this requires background-thread retrieval (not signal-safe).

**Related GitHub issue:** [#6180](https://github.com/getsentry/sentry-cocoa/issues/6180) — `cpu_type` and `cpu_subtype` missing from reports

## Security Considerations

### Memory Introspection During Crash Writing

**Risk:** When collecting memory contents around pointers during crash reporting (`Sources/SentryCrash/Recording/SentryCrashReport.c`), arbitrary memory may be read and included in reports, potentially exposing sensitive data (API keys, user credentials, PII).

**Files:** `Sources/SentryCrash/Recording/SentryCrashReport.c`, `Sources/SentryCrash/Recording/Tools/SentryCrashMemory.c`, `Sources/SentryCrash/Recording/Tools/SentryCrashObjC.c`

**Current mitigation:** User-facing SDK docs recommend disabling crash reporting for apps handling sensitive data; no public option yet to disable memory introspection specifically.

**Recommendations:**

1. Implement a public option (`Options.recordMemoryDump` or similar) to disable memory introspection
2. Document PII risks in crash reporting configuration
3. Consider redaction strategies for sensitive memory patterns (e.g., known credential strings)
4. Audit which functions call `sentrycrashmem_copySafely()` to understand memory capture scope

**Related GitHub issue:** [#7501](https://github.com/getsentry/sentry-cocoa/issues/7501) — Expose public option to disable memory introspection

### Signal Handler Safety Violations

**Risk:** SentryCrash must only call async-signal-safe functions during crash handling. Any violation (e.g., calling `malloc`, `pthread_*`, Objective-C) can cause deadlock or memory corruption.

**Files:** All files in `Sources/SentryCrash/`

**Current mitigation:** Code review guidelines in `REVIEWS.md`; static analysis may catch some violations, but comprehensive enforcement is manual.

**Recommendations:**

1. Add compiler annotations (`__attribute__((no_direct_call_analysis))` or similar) to signal handler paths
2. Document which functions are called from signal context vs. init context
3. Consider running under ThreadSanitizer regularly to catch data races

### App Store Compliance

**Risk:** Certain SentryCrash operations (e.g., calling `NXGetLocalArchInfo()`) are restricted by App Store review and will cause app rejection. Code must detect and skip these operations gracefully.

**Files:** `Sources/SentryCrash/Recording/Tools/SentryCrashCPU.c`

**Current mitigation:** Check for NULL return values; feature degrades gracefully.

**Recommendations:** Document any future App Store API restrictions discovered during testing.

## Performance Bottlenecks

### Session Replay Rate Limiting

**Issue:** `Sources/Swift/Integrations/SessionReplay/SentrySessionReplayIntegration.swift` maintains rate limiting state and segment generation. If rate limits are enforced aggressively, segment 0 (keyframe) may not reach server, breaking replay session initialization on error.

**Files:** `Sources/Swift/Integrations/SessionReplay/SentrySessionReplayIntegration.swift:38-41`

**Symptom:** Session replay segments sent during rate-limited periods are buffered locally but may be discarded before segment 0 is acknowledged by server.

**Cause:** Rate limiting logic treats replay segments like regular events; replay has special requirements for segment ordering.

**Improvement path:** Implement replay-aware rate limiting that:

1. Ensures segment 0 always bypasses rate limits (or has dedicated quota)
2. Prioritizes keyframes over incremental updates
3. Signals rate limit status back to replay recorder to pause capture

### Breadcrumb Disk I/O on Main Thread

**Issue:** Per `develop-docs/DECISIONS.md`, breadcrumbs are written to disk on the main thread to ensure accuracy during OOM crashes. This adds main-thread latency on every breadcrumb capture.

**Files:** Main app thread breadcrumb handling (exact location depends on SentryScope integration points)

**Symptom:** Small but measurable jank on main thread during heavy breadcrumb logging.

**Trade-off:** Accepted design decision to maximize breadcrumb accuracy for OOM crashes (the last breadcrumbs are critical for diagnosis). Alternative would be background thread with potential data loss.

**Recommendation:** Consider async batching with periodic flushes, or detect OOM scenarios to increase write frequency only when at risk.

### View Hierarchy Capture During Crash

**Issue:** When crashes occur, SDK attempts to capture view hierarchy via `Views/SentrySessionReplay` integration. Best-effort capture in crash context may produce empty or incomplete JSON.

**Files:** `Sources/Swift/Integrations/SessionReplay/` (view capture path)

**Symptom:** Session replay "Application State" contains empty view hierarchy for fatal crashes.

**Cause:** View hierarchy capture requires UIKit calls on main thread during async signal handler context, which is unsafe.

**Improvement path:**

1. Pre-capture view hierarchy on a timer during normal execution
2. Use cached snapshot in crash report (avoids unsafe calls)
3. Document limitations in error handling path

**Related GitHub issue:** [#6405](https://github.com/getsentry/sentry-cocoa/issues/6405) — Empty view hierarchy file during fatal crashes

## Fragile Areas

### SentryCrash Cached Data Thread-Local State

**Files:** `Sources/SentryCrash/Recording/SentryCrashCachedData.c`

**Why fragile:** Manages thread and system data via background cache thread. Recent atomic exchange pattern (`freeze()`/`unfreeze()`) fixes race conditions, but the design relies on careful atomic ordering. Any future changes to swap logic risk reintroducing data races or inconsistencies.

**Safe modification:**

- Test all changes with ThreadSanitizer
- Document the freeze/unfreeze lifecycle clearly
- Never add non-atomic assignments to shared pointers
- Use existing atomic patterns consistently

**Test coverage:** Minimal unit tests for C API; most coverage via integration tests.

### C++ Exception Handling

**Files:** `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_CPPException.cpp:69-71`

**Why fragile:** Uses global cursor for C++ exception stack walking instead of thread-local storage (TLS unsupported before iOS 9, which is now deprecated). Future concurrent C++ crashes may race on this global.

**Safe modification:**

- Upgrade minimum iOS version to guarantee TLS availability
- Switch to thread-local storage
- Test on actual devices with concurrent C++ exceptions

**Test coverage:** Limited. No direct unit tests for concurrent C++ exceptions.

### Main Thread Detection in Crash Report

**Files:** `Sources/Sentry/SentryCrashReportConverter.m:268`

**Why fragile:** Crash reports hardcode main thread ID as 0, but error events use dynamic thread ID detection. This inconsistency can cause main thread ID mismatches between crash and transaction traces.

**Safe modification:** Use consistent thread ID detection across both crash and error event paths.

**Test coverage:** Integration tests may not catch thread ID mismatches if tests run serially.

**Related GitHub issue:** [#4904](https://github.com/getsentry/sentry-cocoa/issues/4904) — Different main thread ID for errors vs traces

### Session Replay Integration Touch Tracking

**Files:** `Sources/Swift/Integrations/SessionReplay/SentrySessionReplayIntegration.swift:10`

**Why fragile:** Static `touchTracker` variable exists to avoid retain cycles during swizzling. If swizzling code changes or touch handling changes, this static reference could become stale or leak.

**Safe modification:**

- Never remove the static qualifier without auditing all swizzled methods
- Test touch tracking across app lifecycle (init → background → foreground → crash)
- Verify no circular references with instrumentation

**Test coverage:** UI tests may not catch all touch tracking edge cases.

### Swizzling Infrastructure

**Files:** Multiple files in `Sources/Swift/` perform method swizzling for UIViewController, NSURLSession, and UIView

**Why fragile:** Swizzling is idempotent in theory but depends on careful method signature matching and original implementation preservation. If Apple changes method signatures or behavior, swizzles may fail silently or crash.

**Safe modification:**

- Always check for prior swizzling before applying patches
- Preserve original IMP in closures (never assume linear method lookup)
- Test on actual iOS devices and simulators for each major iOS version
- Monitor for swizzling failures in CI

**Test coverage:** UI tests on iOS 12 (legacy) and current iOS versions in CI.

## Scaling Limits

### Maximum Stacktrace Frames

**Issue:** SDK limits stack traces to 100 frames per function.

**Files:** Likely in `Sources/SentryCrash/Recording/Tools/SentryCrashStackCursor*.c`

**Current capacity:** 100 frames

**Limit:** Some deeply recursive algorithms or framework code may hit this limit, losing valuable stack context.

**Scaling path:** Increase limit to 200+ frames and benchmark memory overhead during crash writing.

**Related GitHub issue:** [#1923](https://github.com/getsentry/sentry-cocoa/issues/1923) — Increase max stacktrace frame length beyond 100

### Report Storage Disk Space

**Issue:** `Sources/SentryCrash/Recording/SentryCrashReportStore.c` stores crash reports on disk. Apps with frequent crashes could exhaust device storage.

**Files:** `Sources/SentryCrash/Recording/SentryCrashReportStore.c`

**Current capacity:** Unknown; likely limited by available disk space

**Limit:** Device storage exhaustion; SDK should implement auto-cleanup of oldest reports.

**Scaling path:** Add configurable max report count or age-based cleanup.

## Test Coverage Gaps

### C API Entry Point

**What's not tested:** `sentrycrash_install()`, `sentrycrash_setMonitoring()`, and callback chain in `Sources/SentryCrash/Recording/SentryCrashC.c:317`

**Files:** `Sources/SentryCrash/Recording/SentryCrashC.c`

**Risk:** Critical initialization code only tested indirectly via integration tests. Bugs in monitor setup or callback wiring may not surface until production.

**Priority:** HIGH

### Report Generation Logic

**What's not tested:** Report writing to disk in `Sources/SentryCrash/Recording/SentryCrashReport.c:1795`. Only tested indirectly via report store tests.

**Files:** `Sources/SentryCrash/Recording/SentryCrashReport.c`

**Risk:** Report format corruption, field ordering bugs, or JSON encoding errors could produce malformed reports that fail server ingestion.

**Priority:** HIGH

### Mach Exception Monitor

**What's not tested:** Direct unit tests for `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_MachException.c:600`. Hard to test safely because signal handlers can't be triggered in test processes.

**Files:** `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_MachException.c`

**Risk:** Mach exception handling on macOS untested; regressions may not surface until production use.

**Priority:** MEDIUM

### Stack Walking Implementations

**What's not tested:** `Sources/SentryCrash/Recording/Tools/SentryCrashStackCursor_Backtrace.c` and `Sources/SentryCrash/Recording/Tools/SentryCrashStackCursor_MachineContext.c`. Only self-thread variant tested.

**Files:** `Sources/SentryCrash/Recording/Tools/SentryCrashStackCursor_*.c`

**Risk:** Cross-thread stack walking bugs (incorrect register reading, frame pointer corruption) may not be caught until production.

**Priority:** MEDIUM

### Architecture-Specific Code

**What's not tested:** ARM64-specific register extraction in `Sources/SentryCrash/Recording/Tools/SentryCrashCPU_arm64.c`. Cannot run on x86_64 simulators.

**Files:** `Sources/SentryCrash/Recording/Tools/SentryCrashCPU_arm64.c`

**Risk:** ARM64-specific bugs (e.g., SIMD register handling, pointer authentication) only caught if tests run on actual devices.

**Priority:** MEDIUM

### Watch OS Exception Handling

**What's not tested:** watchOS exception handling for unhandled exceptions. Test framework limitations prevent watchOS-specific testing.

**Files:** Likely `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_*.c` with `#if os(watchOS)` guards

**Risk:** watchOS crashes may be missed or misreported.

**Priority:** LOW

**Related GitHub issue:** [#2747](https://github.com/getsentry/sentry-cocoa/issues/2747) — Support unhandled exceptions on watchOS

## Dependencies at Risk

### KSCrash Divergence

**Risk:** SentryCrash is a fork of KSCrash (originally by Karl Stenerud, MIT license). Sentry has 270+ independent commits since June 2018, and upstream KSCrash has ~400+ commits in the same period. Significant divergence exists.

**Impact:**

- Upstream bug fixes not adopted into Sentry version
- New features in KSCrash not available
- Maintenance burden of two separate codebases

**Migration plan:**

1. Evaluate which upstream fixes are applicable to Sentry version
2. Consider periodic rebasing or feature cherry-picks
3. Document why certain KSCrash improvements were not adopted (e.g., API incompatibility, Sentry-specific requirements)

**Related documentation:** `develop-docs/SENTRYCRASH.md` contains detailed divergence analysis.

### Swift Language Stability

**Risk:** Large amount of Swift code (277+ files in `Sources/Swift/`). Swift language and ABI stability is solid since Swift 5.0, but future language versions could introduce breaking changes.

**Files:** All files in `Sources/Swift/`

**Impact:** SDK may require Swift version bumps for new iOS/macOS versions; backward compatibility may be limited.

**Mitigation:** Monitor Swift release notes; use feature guards (`#if swift(>=X.Y)`) for experimental features.

### ObjC/Swift Interop

**Risk:** Decision not to use Swift String constants in ObjC code (`develop-docs/DECISIONS.md`, April 11, 2025) due to memory-management bug in Swift standard library for bridging.

**Files:** Any ObjC code using Swift String constants (should be avoided per decision)

**Impact:** Crashes in NSBlock closures accessing Swift strings.

**Mitigation:** Define constants as ObjC `NSString *` instead; document the decision in code comments.

**Related GitHub issue:** [#4887](https://github.com/getsentry/sentry-cocoa/issues/4887)

## Architectural Issues

### v9 Major Version Development

**Issue:** Main branch is currently v9, with v8 maintained in separate `v8.x` branch. v9 is a quality-focused release (per `develop-docs/DECISIONS.md`, "v9").

**Files:** Entire codebase (behind `SDK_V9` compiler flag in CI)

**Impact:** v8 and v9 development must be coordinated carefully. Backports to v8.x branch require double work.

**Recommendation:** Use feature branches liberally; clearly communicate v8 vs. v9 changes in PR descriptions.

### Async SDK Initialization Design

**Issue:** SDK can be initialized from background threads, but `start()` re-schedules initialization to main thread async to avoid deadlocks (`develop-docs/DECISIONS.md`, October 11, 2023).

**Files:** `Sources/Swift/Helper/SentrySDK.swift:94-105`

**Impact:** Apps initializing SDK from background may not have fully initialized SDK immediately after `start()` returns. Some features may not work until main thread schedules and runs initialization.

**Trade-off:** Accepted to avoid deadlocks (e.g., from `@main` Swift initializers). Alternative would be blocking main thread during app launch.

**Safe modification:** Document in API docs that callers should call on main thread; add warnings in logs if called from background.

### SPM vs. xcodebuild Differences

**Issue:** SPM and xcodebuild have different compilation models. SPM cannot mix Swift and ObjC in same target; Sentry uses a prebuilt binary for SPM (`develop-docs/DECISIONS.md`, March 4, 2024).

**Files:** `Package.swift`, binary distribution setup

**Impact:** SPM users get prebuilt SDK; xcodebuild users compile from source. This can lead to version mismatches or unexpected behavior if users mix package managers.

**Recommendation:** Document clearly which package manager to use; avoid cross-package-manager dependencies.

## Missing Critical Features

### Local Symbolication

**Feature gap:** Local symbolication was removed (commit `cd6b26bd1`) due to deadlock risks in signal handlers.

**Blocks:** Better crash debugging without relying on dSYM upload.

**Status:** Deferred; could be re-added as debug-only feature in future.

**Related GitHub issue:** [#6560](https://github.com/getsentry/sentry-cocoa/issues/6560)

### Screenshot Capture for Crashes

**Feature gap:** SDK cannot capture screenshots during crash because screenshot capture requires Objective-C code, which is not async-signal-safe.

**Blocks:** Visual context for crash investigation.

**Status:** Deferred; alternative is best-effort view hierarchy capture.

**Related GitHub decision:** `develop-docs/DECISIONS.md`, April 21, 2022

### Device Architecture Detection

**Feature gap:** `NXGetLocalArchInfo()` blocked by App Store review restrictions; architecture must be inferred at compile time.

**Blocks:** Runtime architecture detection for builds supporting multiple architectures.

**Status:** Workaround exists but incomplete (returns NULL); no public API to retrieve architecture at runtime.

**Related GitHub issue:** [#900](https://github.com/getsentry/sentry-cocoa/issues/900)

---

_Concerns audit: 2026-03-19_
