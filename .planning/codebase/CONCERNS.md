# Codebase Concerns

**Analysis Date:** 2026-02-13

## Tech Debt

### SentryCrash Architecture & Isolation

**Issue:** SentryCrash has tight bidirectional coupling with the SDK, with 55+ files importing SDK headers and 34+ SDK files importing SentryCrash headers. Sentry-specific code (scope sync, session replay, transactions, screenshots) is embedded throughout the crash handling internals.

**Files:**

- `Sources/SentryCrash/` (all monitors and tools)
- `Sources/Sentry/SentryCrashReportConverter.m`
- `Sources/Sentry/SentryCrashReportSink.m`
- `Sources/Sentry/SentryCrashScopeObserver.m`
- `Sources/Sentry/SentryScopeSyncC.c`

**Impact:**

- Difficult to test SentryCrash in isolation
- Hard to adopt upstream KSCrash improvements (forked since June 2018, 270+ independent commits)
- Tight coupling prevents independent evolution
- Signal-safety violations in non-critical paths compromise crash handler reliability

**Fix approach:**

1. Create a clean `SentryCrashFacade` interface - single entry point wrapping all SDK-needed functionality
2. Move Sentry-specific code (scope sync, session replay callbacks) to SDK side, inject via callbacks
3. Extract logging from `SentryAsyncSafeLog.h` to SentryCrash-owned implementation
4. Remove SDK header imports from SentryCrash internals

---

### NSDictionary Introspection Broken in SentryCrash

**Issue:** `sentrycrashobjc_dictionaryCount()` in `SentryCrashObjC.c:1810` is marked "TODO: This is broken" and returns 0. Falls back to generic object introspection.

**Files:** `Sources/SentryCrash/Recording/Tools/SentryCrashObjC.c:1810`

**Impact:** Dictionary contents in crash reports are generic object traces rather than actual key-value pairs. Reduces crash diagnostic value for dictionary-heavy data structures.

**Fix approach:**

- Implement proper dictionary enumeration using Objective-C runtime APIs
- Test against nested/complex dictionaries
- Verify async-signal-safety compliance

---

### CPU Architecture Detection Unavailable

**Issue:** `sentrycrashcpu_currentArch()` in `SentryCrashCPU.c:40` returns NULL. `NXGetLocalArchInfo()` is blocked by App Store for some configurations.

**Files:** `Sources/SentryCrash/Recording/Tools/SentryCrashCPU.c:40-41`

**Impact:** Architecture information missing from crash reports. Loss of context for architecture-specific crashes.

**Fix approach:**

- Use `cpu_type_t` from `sys/sysctl.h` via `CTL_HW` (verified App Store compatible)
- Cache result at install time
- Validate against current deployment targets

---

### Memory Management Race Conditions in UI Tracking

**Issue:** `SentryDefaultUIViewControllerPerformanceTracker.m:53` documents: "memory leaks and crashes due to accessing associated objects from different threads." Associated object access via `objc_setAssociatedObject` is not thread-safe when called from multiple threads.

**Files:**

- `Sources/Sentry/SentryDefaultUIViewControllerPerformanceTracker.m:53-75`
- `Sources/Swift/Core/Tools/ViewCapture/SentryRedactViewHelper.swift:21-49` (also uses objc_setAssociatedObject)

**Impact:** Rare crashes when UI framework callbacks race with SDK teardown or view redaction operations.

**Fix approach:**

- Wrap associated object access in thread-safe critical sections (NSLock)
- Use weak map tables instead of associated objects where possible
- Document thread requirements explicitly

---

### Deadlock Risks in Dispatch Queue Management

**Issue:** Multiple components accept serial dispatch queues with warnings about deadlock potential when methods are called from the queue itself:

- `TelemetryBuffer.swift:74` - Warns against calling from `capturedDataCallback`
- `SentryMetricsBuffer.swift:73` - flushing uses `dispatchSync` which deadlocks if called from buffer's own queue
- `SentryOnDemandReplay.swift:80, 203, 281` - Multiple "must be on processing queue" comments to avoid deadlock
- `SessionReplayFileManager.swift:117` - Race condition between folder mapping and processing

**Files:**

- `Sources/Swift/Tools/TelemetryBuffer/TelemetryBuffer.swift:35-121`
- `Sources/Swift/Integrations/Metrics/SentryMetricsIntegration.swift:88-90`
- `Sources/Swift/Integrations/SessionReplay/SentryOnDemandReplay.swift:80-281`

**Impact:** If callers violate documented contract (calling from wrong queue), code hangs with no obvious cause. Difficult to catch in testing.

**Fix approach:**

- Assert queue identity at entry points using `dispatch_get_specific()`
- Provide async variants that don't require caller queue knowledge
- Add comprehensive queue documentation examples

---

### Thread Safety Race Condition in Logging

**Issue:** `SentrySDKLog.swift` intentionally accepts race conditions between `configure()` (called once at startup) and `log()` (called from multiple threads). Without locks, multiple threads changing log level during operation could see inconsistent state temporarily.

**Files:** `Sources/Swift/Core/Tools/SentrySDKLog.swift:6-15`

**Impact:** Log level changes take time to propagate across threads. Acceptable for startup but documents intentional unsafety. ThreadSanitizer produces false positives.

**Fix approach:**

- Use atomic operations for `isDebug` and `diagnosticLevel` properties
- Declare exceptions in ThreadSanitizer suppressions
- Document why this tradeoff (performance over strict thread-safety) is acceptable

---

### Method Swizzling Complexity & Fragility

**Issue:** Extensive method swizzling throughout the SDK for performance tracking. `SentryNSURLSessionTaskSearch.m` includes a 40-line "WARNING: This code is bulletproof" comment about Apple's internal class hierarchy changes that broke swizzling before.

**Files:**

- `Sources/Sentry/SentryNSURLSessionTaskSearch.m:35-69`
- `Sources/Swift/Core/Integrations/Performance/SentryUIViewControllerSwizzling.swift`
- `Sources/Swift/Core/Tools/ViewCapture/SentryRedactViewHelper.swift:21-49`

**Impact:**

- Fragile to Apple framework updates (already broken before 2015, documented in AFNetworking history)
- Difficult to debug when frameworks change internal structure
- Performance overhead from dynamic method search

**Fix approach:**

- Create integration tests that catch framework changes early
- Document which frameworks are at high risk (NSURLSession, UIViewController)
- Consider moving to modern observation APIs where available (KVO, NSNotification)
- Add CI test for framework API detection

---

### Large, Complex Files with Limited Refactoring

**Issue:** Several files exceed 1000 lines and handle multiple responsibilities:

- `SentryClient.m`: 1155 lines - Event capture, scope application, session management
- `SentryFileManagerHelper.m`: 1019 lines - All file I/O operations, caching, cleanup
- `SentryHub.m`: 967 lines - Hub state, transaction management, thread-local scope
- `SentryTracer.m`: 936 lines - Span lifecycle, profiling integration, frame tracking
- `SentryUIRedactBuilder.swift`: 749 lines - View hierarchy analysis, redaction logic

**Files:** See above

**Impact:**

- High cyclomatic complexity makes testing difficult
- Changes in one area risk breaking unrelated functionality
- Code navigation and understanding become harder
- Increased merge conflict likelihood

**Fix approach:**

- Extract protocol-specific span finishing logic from `SentryTracer.m`
- Move file cleanup strategies in `SentryFileManagerHelper.m` to separate classes
- Break `SentryUIRedactBuilder` into strategy classes for each redaction type
- Prioritize refactoring files modified frequently (check git history)

---

## Known Bugs

### Data Race in Thread Caching (FIXED Feb 10, 2026)

**Status:** FIXED

**What was fixed:** `SentryCrashCachedData.c` had fragile semaphore-based synchronization that could cause `EXC_BAD_ACCESS`. Replaced with atomic exchange pattern from KSCrash PR #733.

**Files:** `Sources/SentryCrash/Recording/SentryCrashCachedData.c`

---

### Concurrent Crash Misidentification (FIXED Feb 2, 2026)

**Status:** FIXED

**What was fixed:** `SentryCrashMonitor.c` incorrectly detected concurrent crashes from different threads as "recrash" events. Fixed with thread-aware atomic guard.

**Files:** `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor.c`

---

## Security Considerations

### Binary Image Cache Thread Safety

**Risk:** `SentryBinaryImageCache.swift:48-54` registers callbacks for binary image add/remove events. Callbacks are invoked from `dyld` on arbitrary threads. Cache is accessed from profiling and stack unwinding code which may run on signal handlers.

**Files:** `Sources/Swift/Core/Helper/SentryBinaryImageCache.swift:48-132`

**Current mitigation:** Uses `NSLock()` for cache access, registered callbacks are async-safe.

**Recommendations:**

- Document which threads can safely read the cache
- Add bounds checking in stack unwinding to handle mid-update cache state
- Consider lock-free data structure for high-frequency profiling reads

---

### Signal Safety Violations in Non-Critical Paths

**Risk:** Code paths that run after crash report is saved (screenshots, view hierarchy, transactions) are documented as "non async-signal-safe code, but since the app is already in a crash state we don't mind if this approach crashes."

**Files:** `Sources/SentryCrash/Recording/SentryCrashC.c` (see onCrash callback)

**Current mitigation:** Happens post-report, so crash during capture doesn't lose data. Documented intentionally.

**Recommendations:**

- Test that these optional captures don't corrupt the saved report
- Consider timing out these operations (5-10ms max)
- Log failures for debugging

---

### Memory Disclosure via Error Context

**Risk:** Error handling captures user-provided error dictionaries which may contain sensitive data (PII, tokens, etc.). `SentryClient.m:254` sanitizes with `sentry_sanitize()`.

**Files:** `Sources/Sentry/SentryClient.m:210-257`, `Sources/Sentry/SentryNSDictionarySanitize.*`

**Current mitigation:** Uses `SentryNSDictionarySanitize` to filter known sensitive keys.

**Recommendations:**

- Audit sanitization patterns against OWASP sensitive data list
- Consider opt-in for custom error dictionary capture
- Document what data gets included in error reports

---

## Performance Bottlenecks

### Expensive View Hierarchy Traversal in Session Replay

**Problem:** Session Replay captures full view hierarchy every frame, walking tree and building render instructions. `SentryUIRedactBuilder.swift:121-647` handles massive nested hierarchies.

**Files:** `Sources/Swift/Core/Tools/ViewCapture/SentryUIRedactBuilder.swift:121-647`

**Cause:** Recursive tree traversal with redaction logic at each node. Complex SwiftUI hierarchies can have 1000+ views.

**Improvement path:**

- Implement incremental capture (detect changed views only)
- Cache view type/redaction decisions
- Profile against Compose-heavy apps (multiple list views, sheets)
- Consider wireframe renderer as low-overhead alternative

---

### Synchronous Dispatch Operations in Teardown

**Problem:** `SentryMetricsIntegration.swift:88-90` documents: "Flushing uses dispatchSync which can deadlock if deinit is called from the buffer's queue."

**Files:** `Sources/Swift/Integrations/Metrics/SentryMetricsIntegration.swift`

**Cause:** Need to flush remaining data before deallocation, but synchrously waits on same queue that might be deallocating.

**Improvement path:**

- Track buffer ownership separately from integration lifecycle
- Use async flush with timeout in deinit
- Test framework shutdown ordering to prevent initialization order issues

---

### NSLog Synchronization Overhead in Tests

**Problem:** `develop-docs/TEST.md:95` documents that "printing messages via NSLog uses synchronization and caused specific tests to fail due to timeouts in CI."

**Files:** `Sources/Swift/Core/Tools/SentrySDKLog.swift:26`

**Cause:** Default log output uses `print()` which is synchronized. Tests with tight loops and debug logs fail timeout assertions.

**Improvement path:**

- Use direct file descriptor writes for test output
- Implement buffered logging for high-volume scenarios
- Provide tunable output flushing

---

## Fragile Areas

### SentryCrash ObjC Runtime Introspection

**Files:** `Sources/SentryCrash/Recording/Tools/SentryCrashObjC.c`

**Why fragile:**

- Multiple TODOs for unimplemented features (dictionary count, bit-field unpacking)
- Direct manipulation of `objc_class` and `ivar_t` structs (private APIs)
- Possible bad access in `sentrycrashobjc_ivarList()` at line 1047
- Uncertainty about tagged pointer NSNumber handling (line 1111)
- Breaks easily if Apple changes private runtime structure layouts

**Safe modification:**

- Add unit tests for each introspection function
- Test against multiple iOS versions (13, 16, 17)
- Use official `<objc/runtime.h>` APIs where possible
- Document private API dependencies with version notes

**Test coverage:** Low - mostly integration tests. Unit tests for individual ivar/method introspection missing.

---

### CPU Architecture and System Info Collection

**Files:**

- `Sources/SentryCrash/Recording/Tools/SentryCrashCPU.c:40-41`
- `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_System.m:326-543`

**Why fragile:**

- CPU detection blocked by App Store (no NXGetLocalArchInfo)
- System info mixing C, ObjC, and Swift levels
- Jailbreak detection uses fragile patterns (file existence checks)
- Direct sysctlbyname calls that may fail or return different data on test devices

**Safe modification:**

- Use official sysctl constants (CTL_HW) instead of string names
- Cache system info at startup, don't re-detect per crash
- Test on simulator + physical devices + various iOS versions
- Document App Store restrictions clearly

**Test coverage:** Medium - `SentryDeviceTests.m` tests some paths but watch OS tests skip major branches (lines 79, 109, 140, 175, 221 have TODOs).

---

### C++ Exception Handling

**Files:** `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_CPPException.cpp:68-233`

**Why fragile:**

- Thread-local storage not available on iOS < 9 (line 68 TODO)
- Uses global stack cursor instead of thread-local (could cause issues with concurrent C++ exceptions)
- `__cxa_throw` hooking is implementation detail-dependent
- Limited test coverage for concurrent exceptions

**Safe modification:**

- Add thread-local storage check at install time
- Implement per-thread exception tracking
- Test against concurrent exception scenarios
- Document iOS version requirements

**Test coverage:** Low - no dedicated C++ exception tests. Swift error tests exist but C++ exceptions are undertested.

---

### Method Swizzling & UIApplication Access

**Files:** `Sources/Swift/Core/Integrations/Performance/SentryUIViewControllerSwizzling.swift:1-130`

**Why fragile:**

- Accesses `UIApplication.shared` at SDK init time, but in SwiftUI apps this may not be available yet
- `SentrySwizzle.m` uses pthread_mutex for thread-safe class method storage
- Depends on Apple's NSURLSession internal class hierarchy (documented as previously broken)
- Xcode 16 introduces ENABLE_DEBUG_DYLIB flag that affects swizzling behavior (see test comment line 190)

**Safe modification:**

- Add early checks for UIApplication availability (use lazy initialization)
- Create integration test that catches NSURLSession hierarchy changes
- Document which Xcode versions have known swizzling issues
- Test on both debug and release builds with different LLVM versions

**Test coverage:** High for happy path. Edge cases (SwiftUI-only, no UIKit, different Xcode versions) have TODOs.

---

## Scaling Limits

### Session Replay Memory Usage with Long Sessions

**Current capacity:** Session replay stores frame data in memory until batch interval (~5 seconds) for compression efficiency.

**Limit:** On devices with <2GB RAM, capturing high-frequency (60fps) sessions with complex hierarchies can exceed allocated memory pool. No automatic memory pressure response.

**Scaling path:**

- Implement memory-aware batching (compress sooner under pressure)
- Reduce capture frequency on low-memory devices (iOS reports)
- Stream replay data to disk instead of buffering in memory
- Implement circular buffer with configurable max size

---

### File Manager Disk Space Management

**Current capacity:** `SentryFileManagerHelper.m:1019` manages crash reports, sessions, replays. No size limit enforced beyond oldest-first eviction.

**Limit:** Large crash reports (with attachments) can quickly fill device storage. No quota system.

**Scaling path:**

- Implement LRU eviction with configurable size quota (default 50MB)
- Compress stored events (currently uncompressed JSON)
- Move old data to separate archive directory
- Monitor free disk space and throttle collection

---

### Profiling Overhead at Scale

**Current capacity:** Continuous profiling samples all thread stacks at configurable interval (default 10ms).

**Limit:** On device with 50+ threads (background processing apps), sampling overhead becomes noticeable. No adaptive sampling.

**Scaling path:**

- Implement adaptive sampling based on CPU/memory pressure
- Skip sampling during known high-contention periods
- Implement thread pool consolidation for background tasks
- Profile against containerized apps with worker thread pools

---

## Dependencies at Risk

### SentryCrash Divergence from KSCrash

**Risk:** SentryCrash was forked in June 2018, now 270+ commits diverged. KSCrash is no longer actively maintained by original author. Security/stability fixes may not propagate.

**Impact:**

- Binary vulnerabilities in crash handling code not patched
- Performance improvements in upstream not adopted
- Incompatibility with new crash types (Metal rendering crashes, etc.)

**Migration plan:**

1. Track KSCrash upstream for relevant commits (monitoring approach active since Feb 2026)
2. Create automated diff tool to identify applicable fixes
3. Establish SentryCrash maintenance plan (quarterly review of upstream)
4. Consider migrating to active KSCrash fork if original becomes unmaintained

---

### Dependency on Private Objective-C Runtime APIs

**Risk:** `SentryCrashObjC.c` uses undocumented `objc_class`, `ivar_t`, `method_t` structs. Apple could change these without notice.

**Impact:** Crashes on future iOS versions where private APIs change layout.

**Migration plan:**

1. Audit which introspection features are truly critical (filter v. nice-to-have)
2. Prioritize official API migration
3. Implement version-specific handling for known structure changes
4. Add CI detection for new iOS betas (parse headers to detect changes)

---

### Memory Safety in C Code

**Risk:** 56.5% of SentryCrash is C utilities with manual memory management, pointer arithmetic, bounds checking.

**Impact:** Buffer overflows, use-after-free, double-free possible in crash handling path.

**Migration plan:**

- Add Address Sanitizer (ASan) to CI test matrix
- Fuzz crash report parsing with malformed inputs
- Migrate critical paths to C++ or Rust (long-term)

---

## Missing Critical Features

### Crash Report Symbolication

**Problem:** Crash reports are sent with unsymbolicated addresses. dSYM upload required server-side.

**Blocks:**

- Offline debugging impossible
- Developers can't use crash logs immediately after build
- CI integration requires dSYM upload step

---

### Custom Crash Types Registration

**Problem:** Only standard crash types monitored (signal, Mach exception, NSException, C++ exception). No extension point for custom crash sources.

**Blocks:**

- Third-party frameworks can't register custom crash types
- WatchOS/tvOS-specific crashes may not be detected
- Metal/GameKit crashes fall through

---

### Incremental Replay Capture

**Problem:** Session replay captures entire frame every tick (60fps), no delta/incremental update support.

**Blocks:**

- Cannot achieve < 5fps effective replay on low-end devices
- Bandwidth usage inefficient for static screens
- Network transfers unnecessarily large

---

## Test Coverage Gaps

### SentryCrash Core C Functionality

**What's not tested:**

- `SentryCrashObjC.c` - ObjC runtime introspection (dictionary count, ivar list, method iteration)
- `SentryCrashCPU.c` - CPU context capture and unwinding
- `SentryCrashMonitor_CPPException.cpp` - C++ exception handling under concurrent throws
- Stack cursor implementation for various architectures

**Files:** `Sources/SentryCrash/Recording/Tools/SentryCrashObjC.c`, `SentryCrashCPU.c`, `SentryCrash*.cpp`

**Risk:** High - these are core crash detection paths. A bug here means crashes aren't captured or are corrupted.

**Priority:** HIGH

---

### Signal Handler Safety

**What's not tested:**

- Signal handler behavior under actual signal delivery
- Nested signals (signal during signal handler execution)
- Signal safety of all code paths in handlers

**Files:** `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_Signal.c`

**Risk:** High - signal handlers must be async-safe or OS may terminate process.

**Priority:** HIGH

---

### Thread Safety of Associated Objects

**What's not tested:**

- `objc_setAssociatedObject` called from multiple threads simultaneously
- View teardown while redaction in progress
- Memory leaks from associated object cycles

**Files:** `Sources/Swift/Core/Tools/ViewCapture/SentryRedactViewHelper.swift`, `SentryDefaultUIViewControllerPerformanceTracker.m`

**Risk:** Medium - manifests as rare crashes in production under specific timing conditions.

**Priority:** MEDIUM

---

### UI Framework Swizzling Across Versions

**What's not tested:**

- NSURLSession on iOS 13, 14, 15, 16, 17, 18 (test coverage jumps around)
- UIViewController hierarchy with modern SwiftUI integration
- Private framework changes detected early

**Files:** `Sources/Swift/Core/Integrations/Performance/SentryUIViewControllerSwizzling.swift`

**Risk:** Medium - breaks silently in certain iOS versions without clear error.

**Priority:** MEDIUM

---

### File Manager Edge Cases

**What's not tested:**

- Disk full scenarios
- Concurrent writes from multiple threads
- Cleanup race conditions
- Large event serialization (100MB+ attachments)

**Files:** `Sources/Sentry/SentryFileManagerHelper.m:1019`

**Risk:** Medium - production failures when device storage limits reached.

**Priority:** MEDIUM

---

### SwiftUI Session Replay Redaction

**What's not tested:**

- Complex nested ScrollView/LazyVStack hierarchies
- Custom SwiftUI shapes and canvas drawings
- Accessibility hierarchy vs. visual hierarchy mismatches
- Performance with 1000+ view hierarchies

**Files:** `Sources/Swift/Core/Tools/ViewCapture/SentryUIRedactBuilder.swift:121-647`

**Risk:** Medium - over/under redaction of sensitive data, performance hangs.

**Priority:** MEDIUM

---

## Recommendations Summary

**Immediate (HIGH):**

1. Fix NSDictionary introspection in SentryCrash (diagnostic value)
2. Add thread safety to associated object access (crash prevention)
3. Add unit tests for SentryCrash C introspection (coverage)

**Short-term (MEDIUM):**

1. Create SentryCrashFacade to decouple SDK and SentryCrash
2. Implement deadlock detection tests for dispatch queue operations
3. Break up large files (>1000 lines) into smaller components
4. Add SwiftUI view hierarchy performance benchmarks

**Long-term (LOW):**

1. Migrate SentryCrash to be independently testable and maintainable
2. Track KSCrash upstream and apply relevant fixes systematically
3. Implement incremental session replay capture
4. Add extensible crash type registration system

---

_Concerns audit: 2026-02-13_
