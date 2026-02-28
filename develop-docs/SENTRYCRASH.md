# SentryCrash: Analysis & Improvement Plan

## Table of Contents

- [Problem Statement](#problem-statement)
- [Phase 0: Knowledge Building](#phase-0-knowledge-building)
  - [Component Overview](#component-overview)
  - [Architecture Deep Dive](#architecture-deep-dive)
  - [KSCrash Divergence Analysis](#kscrash-divergence-analysis)
  - [Known Issues & Risks](#known-issues--risks)
- [Phase 1: Isolation (Public API)](#phase-1-isolation-public-api)
- [Phase 2: Confidence (Test Coverage)](#phase-2-confidence-test-coverage)
- [Phase 3: Architecture (Internal Structure)](#phase-3-architecture-internal-structure)
- [Phase 4: Documentation & Knowledge Sharing](#phase-4-documentation--knowledge-sharing)
- [Phase 5: Fix the Bugs](#phase-5-fix-the-bugs)

---

## Problem Statement

SentryCrash is the **backbone of the Sentry Cocoa SDK** -- it handles all crash detection and reporting. However:

- **Heavily diverged from KSCrash**: Forked in June 2018, with 270+ independent commits over 8 years
- **Limited team knowledge**: The low-level C/ObjC crash handling code is specialized and not well understood across the team
- **Very little test coverage**: Core C-level crash handling code has minimal direct unit tests
- **Tight coupling**: Bidirectional dependencies between SentryCrash and the SDK, with Sentry-specific code embedded throughout

---

## Phase 0: Knowledge Building

### Component Overview

| Metric                  | Value                                                                  |
| ----------------------- | ---------------------------------------------------------------------- |
| **Total files**         | 84 files (36 .h, 36 .c, 11 .m, 1 .cpp)                                 |
| **Total lines of code** | ~21,000                                                                |
| **Location**            | `Sources/SentryCrash/`                                                 |
| **Languages**           | C (primary), Objective-C, C++, Swift (wrappers)                        |
| **Test files**          | ~49 across `Tests/SentryTests/SentryCrash/`                            |
| **Original source**     | [KSCrash](https://github.com/kstenerud/KSCrash) by Karl Stenerud (MIT) |

### Architecture Deep Dive

#### Directory Structure

```
Sources/SentryCrash/
├── Installations/                     # Lifecycle management (221 lines)
│   └── SentryCrashInstallation.m
├── Recording/                         # Core crash recording (4,774 lines)
│   ├── SentryCrash.m                  # Main ObjC class (219 lines)
│   ├── SentryCrashC.c                 # C API entry point (486 lines)
│   ├── SentryCrashReport.c            # Report writing to disk
│   ├── SentryCrashReportStore.c       # Report storage/retrieval
│   ├── SentryCrashReportFixer.c       # Post-processing crash reports
│   ├── SentryCrashCachedData.c        # Thread/system data caching
│   ├── SentryCrashBinaryImageCache.c  # Binary image tracking
│   ├── SentryCrashDoctor.m            # Report analysis
│   ├── Monitors/                      # Crash detection (3,224 lines)
│   │   ├── SentryCrashMonitor.c           # Central monitor dispatcher
│   │   ├── SentryCrashMonitor_MachException.c  # Mach kernel exceptions
│   │   ├── SentryCrashMonitor_Signal.c         # POSIX signals
│   │   ├── SentryCrashMonitor_NSException.m    # ObjC exceptions
│   │   ├── SentryCrashMonitor_CPPException.cpp # C++ exceptions
│   │   ├── SentryCrashMonitor_System.m         # System info collection
│   │   └── SentryCrashMonitor_AppState.c       # App state tracking
│   └── Tools/                         # Utilities (11,872 lines -- 56% of codebase)
│       ├── SentryCrashCPU*.c          # CPU context (arm, arm64, x86, x86_64)
│       ├── SentryCrashStackCursor*.c  # Stack unwinding
│       ├── SentryCrashMach*.c         # Mach kernel interfaces
│       ├── SentryCrashObjC.c          # ObjC runtime introspection
│       ├── SentryCrashJSONCodec.c     # JSON encoder (C)
│       ├── SentryCrashFileUtils.c     # File I/O utilities
│       └── ... (20+ more utility files)
└── Reporting/                         # Report filtering (934 lines)
    └── Filters/
        ├── SentryCrashReportFilterBasic.m
        └── Tools/
            └── SentryDictionaryDeepSearch.m
```

#### Lines of Code by Subsystem

```
Recording/Tools:     11,872 lines (56.5%)  ← Most code lives here
Recording/ (base):    4,774 lines (22.7%)
Recording/Monitors:   3,224 lines (15.3%)
Reporting/:             934 lines  (4.4%)
Installations/:         221 lines  (1.1%)
```

#### Crash Detection Flow

```
1. App crashes (signal, Mach exception, NSException, or C++ exception)
     ↓
2. Appropriate monitor detects the crash:
   - SentryCrashMonitor_MachException → Mach kernel exceptions
   - SentryCrashMonitor_Signal       → POSIX signals (SIGSEGV, SIGABRT, etc.)
   - SentryCrashMonitor_NSException  → Objective-C exceptions
   - SentryCrashMonitor_CPPException → C++ exceptions via __cxa_throw hook
     ↓
3. Monitor populates SentryCrash_MonitorContext with crash details
     ↓
4. Global onCrash() callback invoked (SentryCrashC.c:75)
   ├── Updates app state: sentrycrashstate_notifyAppCrash()
   ├── Writes crash report to disk: sentrycrashreport_writeStandardReport()
   ├── Saves session replay: sentrySessionReplaySync_writeInfo()
   ├── Saves screenshots/view hierarchy (non-signal-safe, best-effort)
   └── Saves active transaction: g_saveTransaction()
     ↓
5. App terminates (if fatal crash)
     ↓
6. On NEXT launch:
   ├── SentryCrashIntegration.startCrashHandler()
   ├── Retrieves pending reports: reportIDs() → reportWithID()
   ├── SentryCrashReportSink processes and transforms reports
   ├── SentryCrashReportConverter → SentryEvent
   └── Events sent to Sentry backend
```

#### SDK Integration Points

The SDK integrates with SentryCrash through these key files:

| File                                                                           | Role                                                     |
| ------------------------------------------------------------------------------ | -------------------------------------------------------- |
| `Sources/Swift/Integrations/SentryCrash/SentryCrashIntegration.swift`          | Main integration, implements `SwiftIntegration` protocol |
| `Sources/Swift/Integrations/SentryCrash/SentryCrashInstallationReporter.swift` | Sentry-specific `SentryCrashInstallation` subclass       |
| `Sources/Swift/Integrations/SentryCrash/SentryCrashWrapper.swift`              | Testability wrapper around C API                         |
| `Sources/Sentry/SentryCrashReportConverter.m`                                  | Transforms raw crash reports → `SentryEvent`             |
| `Sources/Sentry/SentryCrashReportSink.m`                                       | Implements `SentryCrashReportFilter` for Sentry          |
| `Sources/Sentry/SentryCrashScopeObserver.m`                                    | Syncs SDK scope → SentryCrash via C interface            |
| `Sources/Sentry/SentryScopeSyncC.c`                                            | C interface for scope synchronization at crash time      |

#### Initialization Sequence

```
SentrySDK.start(options:)
  → SentryHub creation → SentryClient init → Install integrations
    → SentryCrashIntegration.init (if enableCrashHandler = true)
      ├── Create SentryCrashWrapper
      ├── Create SentryCrashScopeObserver
      ├── Create SentryCrashIntegrationSessionHandler
      └── startCrashHandler():
          ├── SentryCrashInstallationReporter.install(cacheDirectory)
          │   └── C: sentrycrash_install(appName, installPath)
          ├── Serialize scope → sentrycrash_setUserInfoJSON()
          ├── Register scope observer for live updates
          ├── sentrycrash_setSaveTransaction(callback)
          ├── sentrycrashcm_setEnableSigtermReporting()
          └── installation.sendAllReports() ← sends pending crash reports
```

### KSCrash Divergence Analysis

#### Timeline

| Date          | Event                                                           |
| ------------- | --------------------------------------------------------------- |
| **June 2018** | Initial KSCrash fork added to sentry-cocoa (commit `edc4eabff`) |
| **Sept 2018** | Symbol renaming: KS* → SentryCrash* (commit `2dfe7fe68`)        |
| **Jan 2021**  | Fixed symbol clashes with apps also using KSCrash               |
| **June 2025** | Added C++ exception capturing via `__cxa_throw` hook            |
| **Oct 2025**  | Major Swift migration of wrapper classes                        |
| **Feb 2026**  | Latest upstream alignment with KSCrash (selective cherry-picks) |

**Total independent commits**: 270+ over 8 years

#### Naming Convention

All original KS-prefixed symbols were renamed to Sentry prefixes:

- Files: `KSCrash.m` → `SentryCrash.m`
- Functions: `kscrash_install()` → `sentrycrash_install()`
- Types: `KSCrashMonitorType` → `SentryCrashMonitorType`

**No KS-prefixed files remain** in the current codebase.

#### Sentry-Specific Additions (Not in KSCrash)

These features were added by Sentry and do not exist in upstream KSCrash:

1. **Scope Synchronization** (`SentryScopeSyncC.c/.h`)
   - Syncs user, tags, breadcrumbs, context, trace to crash handler memory
   - Accessed during crash via `sentrycrash_scopesync_getScope()`

2. **Transaction Callback** (in `SentryCrashC.c`)
   - `sentrycrash_setSaveTransaction(callback)` -- saves active tracing transaction at crash time
   - Callback defined with `@_cdecl` in Swift

3. **Session Replay Integration** (in `SentryCrashC.c`)
   - `sentrySessionReplaySync_writeInfo()` called during crash callback

4. **Binary Image Cache Hooks** (`SentryCrashBinaryImageCache.c`)
   - `sentry_setRegisterFuncForAddImage/RemoveImage()` for custom dyld tracking
   - Enables real-time binary image change tracking for profiling

5. **Screenshot/View Hierarchy Callbacks** (in `SentryCrashC.c`)
   - `sentrycrash_setSaveScreenshots()`, `sentrycrash_setSaveViewHierarchy()`
   - Best-effort non-signal-safe capture at crash time

6. **Async-Safe Logging** (`SentryAsyncSafeLog.c/.h`)
   - Signal-safe logging replacing NSLog in crash handlers

7. **NSException Stack Cursor** (`SentryCrashMonitor_NSException_StackCursor.*`)
   - Added Jan 2026 for better NSException stack trace capture

8. **C++ Exception Swapper** (`SentryCrashCxaThrowSwapper.c/.h`)
   - Runtime `__cxa_throw` hooking (inspired by fishhook + Yandex approach)

#### Recent Upstream Alignment (2026)

Sentry maintains a watching approach, selectively adopting KSCrash improvements:

- `0f752caf6` (Feb 2026): "align with upstream KSCrash"
- `9c801d311` (Feb 2026): Adopted lock-free atomic exchange from KSCrash PR #733
- `5bd268cae` (Feb 2026): "suspend env after notifying, align naming with KSCrash"

### Known Issues & Risks

#### HIGH Priority

| Issue                                  | Status               | Details                                                                                                                                               |
| -------------------------------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Data race in thread caching**        | FIXED (Feb 10, 2026) | `SentryCrashCachedData.c` had fragile semaphore-based sync. Replaced with atomic exchange pattern from KSCrash PR #733. Was causing `EXC_BAD_ACCESS`. |
| **Concurrent crash misidentification** | FIXED (Feb 2, 2026)  | `SentryCrashMonitor.c` incorrectly detected concurrent crashes from different threads as "recrash". Fixed with thread-aware atomic guard.             |

#### MEDIUM Priority

| Issue                                       | File                                     | Details                                                                                                                   |
| ------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| **NSDictionary introspection broken**       | `SentryCrashObjC.c:1810`                 | Marked "TODO: This is broken". `sentrycrashobjc_dictionaryCount()` returns 0. Falls back to generic object introspection. |
| **CPU architecture detection unavailable**  | `SentryCrashCPU.c:40`                    | `sentrycrashcpu_currentArch()` returns NULL. `NXGetLocalArchInfo()` blocked by App Store.                                 |
| **Thread-local storage for C++ exceptions** | `SentryCrashMonitor_CPPException.cpp:68` | Global stack cursor instead of thread-local. Could cause issues with concurrent C++ exceptions.                           |
| **Mach exception freeze workaround**        | `SentryCrashMonitor_MachException.c:340` | "TODO: This was put here to avoid a freeze. Does secondary thread ever fire?"                                             |
| **Unimplemented report sections**           | `SentryCrashReport.c:653`                | "TODO: Implement these" for NSDictionary and NSException introspection cases.                                             |

#### LOW Priority (TODOs & Technical Debt)

| File                          | Line     | TODO                                                                 |
| ----------------------------- | -------- | -------------------------------------------------------------------- |
| `SentryCrashMonitor_System.m` | 406, 531 | "use SentryDevice API here now?" / "combine this into SentryDevice?" |
| `SentryCrashObjC.c`           | 1047     | Possible bad access in `sentrycrashobjc_ivarList`                    |
| `SentryCrashObjC.c`           | 1111     | Uncertainty about tagged pointer NSNumber handling                   |
| `SentryCrashObjC.c`           | 1691     | Bit-field unpacking not implemented for mutable arrays               |

#### Async-Signal-Safety Concerns

The crash handlers generally follow signal-safety rules:

- Use `SENTRY_ASYNC_SAFE_LOG_*` macros (no malloc/NSLog)
- Signal handler (`handleSignal()`) uses only async-safe functions
- Mach exception handler runs on a dedicated thread (not in signal context)

**Known exceptions** (documented, intentional):

- Screenshot/view hierarchy capture after report is saved (documented as "non async-signal safe code, but since the app is already in a crash state we don't mind if this approach crashes")
- Transaction save callback similarly best-effort

---

## Phase 1: Isolation (Public API)

### Current Public API Surface

SentryCrash's public API is exposed through headers in `Sources/Sentry/include/`:

#### C API (`SentryCrashC.h`)

```c
SentryCrashMonitorType sentrycrash_install(const char *appName, const char *installPath);
void sentrycrash_uninstall(void);
SentryCrashMonitorType sentrycrash_setMonitoring(SentryCrashMonitorType monitors);
void sentrycrash_setUserInfoJSON(const char *userInfoJSON);
void sentrycrash_setCrashNotifyCallback(SentryCrashReportWriteCallback onCrashNotify);
void sentrycrash_setSaveScreenshots(void (*callback)(const char *));
void sentrycrash_setSaveViewHierarchy(void (*callback)(const char *));
void sentrycrash_setSaveTransaction(void (*callback)(void));
```

#### ObjC API (`SentryCrash.h`)

```objc
@interface SentryCrash
@property NSString *basePath;
@property NSDictionary *userInfo;
@property SentryCrashMonitorType monitoring;
@property int maxReportCount;
- (SentryCrashMonitorType)install:(NSString *)cacheDirPath;
- (void)uninstall;
- (NSArray *)reportIDs;
- (NSDictionary *)reportWithID:(int64_t)reportID;
- (void)deleteReportWithID:(int64_t)reportID;
- (void)sendAllReportsWithCompletion:(SentryCrashReportFilterCompletion)onCompletion;
@end
```

#### Supporting Public Headers

| Header                           | Purpose                                          |
| -------------------------------- | ------------------------------------------------ |
| `SentryCrashMonitorType.h`       | Monitor type enums (MachException, Signal, etc.) |
| `SentryCrashReportFilter.h`      | Report filter protocol and completion callback   |
| `SentryCrashInstallation.h`      | Installation base class                          |
| `SentryCrashBinaryImageCache.h`  | Binary image tracking API                        |
| `SentryCrashStackCursor.h`       | Stack unwinding cursor types                     |
| `SentryCrashMachineContext.h`    | Machine context wrapper types                    |
| Various `SentryCrashMonitor_*.h` | Individual monitor APIs                          |

### Coupling Analysis

**SDK → SentryCrash** (34 non-SentryCrash files import SentryCrash headers):

- `SentryClient.m`, `SentrySDKInternal.m`, `SentryCrashReportConverter.m`, `SentryCrashReportSink.m`
- `SentryCrashScopeObserver.m`, `SentryDefaultThreadInspector.m`, `SentryDefaultAppStateManager.m`
- `SentrySpanInternal.m`, `SentrySessionReplaySyncC.c`, plus ~25 more

**SentryCrash → SDK** (55+ SentryCrash files import SDK headers):

- All monitors import `SentryAsyncSafeLog.h`, `SentryInternalCDefines.h`
- `SentryCrashC.c` imports `SentrySessionReplaySyncC.h`
- Many tools import `SentryDefines.h`, `SentryScopeSyncC.h`

### Recommendations for Isolation

1. **Define a clean boundary interface**: Create a single protocol/interface that the SDK uses to interact with SentryCrash, rather than importing 17+ headers directly
2. **Extract Sentry-specific code from SentryCrash internals**: Move scope sync, session replay sync, and transaction callbacks to the SDK side, injected via callbacks
3. **Remove SDK header imports from SentryCrash**: Replace `SentryAsyncSafeLog.h`, `SentryInternalCDefines.h`, etc. with SentryCrash-owned equivalents or inject them
4. **Create a `SentryCrashFacade`**: Single entry point wrapping all SentryCrash functionality the SDK needs

---

## Phase 2: Confidence (Test Coverage)

### Current Test Coverage

**Test file location**: `Tests/SentryTests/SentryCrash/` (49 files)

| Category               | Count | Examples                                                              |
| ---------------------- | ----- | --------------------------------------------------------------------- |
| ObjC tests (.m)        | 29    | `SentryCrashJSONCodec_Tests.m`, `SentryCrashObjC_Tests.m`             |
| Swift tests (.swift)   | 18    | `SentryCrashInstallationTests.swift`, `SentryCrashWrapperTests.swift` |
| C++/ObjC++ tests (.mm) | 2     | `SentryCrashMonitor_CppException_Tests.mm`                            |

**Integration tests**: `Tests/SentryTests/Integrations/SentryCrash/SentryCrashIntegrationTests.swift`

### Well-Tested Subsystems

| Subsystem                | Test Files                                                            | Coverage Level |
| ------------------------ | --------------------------------------------------------------------- | -------------- |
| JSON codec               | `SentryCrashJSONCodec_Tests.m`                                        | Good           |
| ObjC introspection       | `SentryCrashObjC_Tests.m`                                             | Good           |
| Report filtering         | `SentryCrashReportFilter_Tests.m`                                     | Good           |
| Report fixing            | `SentryCrashReportFixer_Tests.m`                                      | Good           |
| Mach/Mach-O handling     | `SentryCrashMach_Tests.m`, `SentryCrashMach-OTests.m`                 | Good           |
| NSException monitor      | `SentryCrashMonitor_NSException_Tests.m`                              | Good           |
| Signal monitor           | `SentryCrashMonitor_Signal_Tests.m`                                   | Good           |
| Binary image cache       | `SentryCrashBinaryImageCacheTests.m`                                  | Good           |
| Swift wrappers           | `SentryCrashWrapperTests.swift`, `SentryCrashInstallationTests.swift` | Good           |
| Integration (end-to-end) | `SentryCrashIntegrationTests.swift`                                   | Good           |

### UNTESTED or Minimally Tested Components

**Critical -- no direct unit tests:**

| File                                      | Lines  | Risk   | Notes                                                                 |
| ----------------------------------------- | ------ | ------ | --------------------------------------------------------------------- |
| `SentryCrashC.c`                          | 486    | HIGH   | Main C API entry point. Only tested indirectly via integration tests. |
| `SentryCrashReport.c`                     | ~1,500 | HIGH   | Report writing logic. Only tested indirectly via report store tests.  |
| `SentryCrashMonitor_MachException.c`      | ~650   | HIGH   | Mach exception handling. No direct tests (hard to test safely).       |
| `SentryCrashCachedData.c`                 | ~250   | HIGH   | Thread caching with recent race fix. No direct tests.                 |
| `SentryCrashMemory.c`                     | ~200   | MEDIUM | Memory reading utilities. No tests.                                   |
| `SentryCrashStackCursor.c`                | ~150   | MEDIUM | Base stack walker. Only self-thread variant tested.                   |
| `SentryCrashStackCursor_Backtrace.c`      | ~100   | MEDIUM | Backtrace-based walking. No tests.                                    |
| `SentryCrashStackCursor_MachineContext.c` | ~100   | MEDIUM | Machine context walking. No tests.                                    |

**Architecture-specific code (no tests):**

| File                      | Risk                                     |
| ------------------------- | ---------------------------------------- |
| `SentryCrashCPU_arm64.c`  | MEDIUM -- primary architecture, untested |
| `SentryCrashCPU_x86_64.c` | LOW -- simulator/macOS only              |
| `SentryCrashCPU_arm.c`    | LOW -- deprecated 32-bit                 |
| `SentryCrashCPU_x86_32.c` | LOW -- deprecated 32-bit                 |

**SDK integration components (no unit tests):**

| File                                        | Risk                             |
| ------------------------------------------- | -------------------------------- |
| `SentryCrashExceptionApplication.m`         | LOW                              |
| `SentryCrashDefaultMachineContextWrapper.m` | LOW                              |
| `SentryCrashScopeObserver.m`                | MEDIUM -- only integration tests |

### Recommendations for Improving Test Coverage

1. **Priority 1 -- Test the C API**: Write tests for `sentrycrash_install()`, `sentrycrash_setMonitoring()`, and the `onCrash()` callback chain using a mock monitor
2. **Priority 2 -- Test report generation**: Create unit tests for `SentryCrashReport.c` that verify report structure and field correctness
3. **Priority 3 -- Test cached data**: Unit test the new atomic exchange pattern in `SentryCrashCachedData.c`, especially the `freeze()`/`unfreeze()` lifecycle
4. **Priority 4 -- Test stack cursors**: Test `SentryCrashStackCursor_Backtrace.c` and `SentryCrashStackCursor_MachineContext.c`
5. **Priority 5 -- Platform-specific tests**: Add ARM64 register extraction tests (can run on device or simulator)

**Testing challenges**: Many low-level crash components are inherently hard to test because:

- Signal handlers can't be safely triggered in test processes
- Mach exception handling requires kernel interaction
- Some error paths require resource exhaustion conditions
- Architecture-specific code needs specific hardware

**Recommended approaches**:

- Use mock monitors and contexts for testing the reporting pipeline
- Test C functions in isolation by calling them directly with crafted inputs
- Use `DYLD_INTERPOSE` where possible for function interposition
- Document untestable paths following the project's existing convention

---

## Phase 3: Architecture (Internal Structure)

### Current Architecture Issues

#### 1. Monolithic Tools Directory

The `Recording/Tools/` directory contains **56% of all SentryCrash code** (11,872 lines across 20+ files) with no further organization. Files range from CPU-specific register handling to JSON encoding to ObjC runtime introspection.

#### 2. Implicit Dependencies via Global State

Many components communicate through global variables:

- `g_installed`, `g_monitoring` in `SentryCrashC.c`
- `g_allMachThreads`, `g_allPThreads` in `SentryCrashCachedData.c`
- `g_isHandlingCrash` in `SentryCrashMonitor.c`
- Function pointer callbacks: `g_saveScreenShot`, `g_saveViewHierarchy`, `g_saveTransaction`

#### 3. Mixed Abstraction Levels

The same directory mixes:

- High-level ObjC wrappers (`SentryCrash.m`)
- Mid-level C APIs (`SentryCrashC.c`)
- Low-level kernel interfaces (`SentryCrashMach.c`)
- Architecture-specific code (`SentryCrashCPU_arm64.c`)

#### 4. Legacy Code

- 32-bit ARM and x86 code still present (deprecated since iOS 11 and macOS 10.15)
- `sentrycrashcpu_currentArch()` permanently returns NULL due to App Store restrictions
- NSDictionary introspection marked as "broken" but still present

### Recommendations for Architecture Improvement

1. **Reorganize Tools/ into sub-modules**:
   ```
   Tools/
   ├── CPU/          (SentryCrashCPU*.c)
   ├── StackWalking/ (SentryCrashStackCursor*.c, SentryCrashMachineContext.c)
   ├── Kernel/       (SentryCrashMach.c, SentryCrashMach-O.c, SentryCrashThread.c)
   ├── Introspection/(SentryCrashObjC.c, SentryCrashNSErrorUtil.m)
   ├── Serialization/(SentryCrashJSONCodec.c, SentryCrashJSONCodecObjC.m)
   └── System/       (SentryCrashSysCtl.c, SentryCrashMemory.c, SentryCrashFileUtils.c)
   ```

2. **Replace global state with explicit dependency injection** where feasible (understanding that some globals are necessary for signal-handler constraints)

3. **Remove deprecated 32-bit code** (`SentryCrashCPU_arm.c`, `SentryCrashCPU_x86_32.c`) -- these platforms haven't been supported since 2019

4. **Continue Swift migration**: The ongoing effort to wrap C components in Swift (already done for `SentryCrashWrapper`, `SentryCrashInstallationReporter`) should continue for the higher-level components

---

## Phase 4: Documentation & Knowledge Sharing

### Current Documentation State

- `develop-docs/ARCHITECTURE.md`: One line mentioning SentryCrash: "Originally forked from KSCrash and independently evolved since then"
- `THIRD_PARTY_NOTICES.md`: License attribution to Karl Stenerud
- Source file headers: "Adapted from: https://github.com/kstenerud/KSCrash"
- Inline comments: Variable quality; some well-documented, some TODOs from years ago

### Recommendations

1. **This document** (`develop-docs/SENTRYCRASH.md`) serves as the starting knowledge base
2. **Create architecture diagrams** showing:
   - Monitor system flow (crash detection → report writing → next-launch recovery)
   - Data flow between SDK and SentryCrash
   - Thread model (which threads run what code during/after crash)
3. **Document signal-safety rules**: What functions can be called in crash context, and why
4. **Create onboarding guide**: Step-by-step for new team members to understand SentryCrash
5. **Document Sentry-specific modifications**: Maintain a clear list of what's been added/changed vs upstream KSCrash (see [Sentry-Specific Additions](#sentry-specific-additions-not-in-kscrash) above)

---

## Phase 5: Fix the Bugs

### Recently Fixed (for reference)

| Date         | Issue                                                   | Commit      |
| ------------ | ------------------------------------------------------- | ----------- |
| Feb 10, 2026 | Data race in `SentryCrashCachedData.c` (EXC_BAD_ACCESS) | `9c801d311` |
| Feb 2, 2026  | Concurrent crashes misidentified as recrash             | `ee1f08693` |
| Jan 2026     | NSException stack cursor implementation                 | `a95a2c6eb` |
| Oct 2025     | Crashed thread missing from thread list                 | `b115f8270` |
| Oct 2025     | Thread deallocation issues                              | `f4f94f525` |
| Sept 2025    | App launch hang caused by SDK                           | `ea12acf4a` |
| Nov 2025     | Remove symbolication causing deadlocks                  | `cd6b26bd1` |

### Open Issues to Address

| Priority | Issue                                   | Location                                          | Description                                          |
| -------- | --------------------------------------- | ------------------------------------------------- | ---------------------------------------------------- |
| MEDIUM   | NSDictionary introspection broken       | `SentryCrashObjC.c:1810`                          | `sentrycrashobjc_dictionaryCount()` always returns 0 |
| MEDIUM   | CPU arch detection returns NULL         | `SentryCrashCPU.c:40`                             | `NXGetLocalArchInfo()` blocked by App Store          |
| MEDIUM   | Mach exception freeze workaround        | `SentryCrashMonitor_MachException.c:340`          | Unclear if secondary thread fires                    |
| MEDIUM   | Unimplemented report introspection      | `SentryCrashReport.c:653`                         | NSDictionary/NSException cases not implemented       |
| LOW      | Thread-local storage for C++ exceptions | `SentryCrashMonitor_CPPException.cpp:68`          | Global cursor, potential concurrent issue            |
| LOW      | SentryDevice API consolidation          | `SentryCrashMonitor_System.m:406,531`             | Duplicate device info collection                     |
| LOW      | Deprecated 32-bit platform code         | `SentryCrashCPU_arm.c`, `SentryCrashCPU_x86_32.c` | Dead code, maintenance burden                        |

---

## Appendix: Key File Reference

### Most Critical Files (must understand these)

| File                                                    | Purpose                                           | Lines  |
| ------------------------------------------------------- | ------------------------------------------------- | ------ |
| `Recording/SentryCrashC.c`                              | C API, installation, crash callback orchestration | 486    |
| `Recording/SentryCrash.m`                               | ObjC wrapper, configuration management            | 219    |
| `Recording/SentryCrashReport.c`                         | Crash report writing to disk (signal-safe)        | ~1,500 |
| `Recording/SentryCrashCachedData.c`                     | Thread/system data caching (lock-free)            | ~250   |
| `Recording/Monitors/SentryCrashMonitor.c`               | Monitor registry and dispatch                     | ~350   |
| `Recording/Monitors/SentryCrashMonitorContext.h`        | Unified crash context structure                   | ~200   |
| `Recording/Monitors/SentryCrashMonitor_MachException.c` | Mach kernel exception handler                     | ~650   |
| `Recording/Monitors/SentryCrashMonitor_Signal.c`        | POSIX signal handler                              | ~350   |

### Platform Availability Guards

| Guard                     | Platforms                                       |
| ------------------------- | ----------------------------------------------- |
| `SENTRY_HAS_MACH`         | iOS, macOS, tvOS, watchOS, visionOS (all Apple) |
| `SENTRY_HAS_SIGNAL`       | All Apple platforms                             |
| `SENTRY_HAS_SIGNAL_STACK` | All Apple platforms                             |
| `SENTRY_HAS_THREADS_API`  | All Apple platforms                             |
| `__arm64__`               | iOS devices, Apple Silicon Macs                 |
| `__x86_64__`              | Intel Macs, iOS Simulator (Intel)               |
