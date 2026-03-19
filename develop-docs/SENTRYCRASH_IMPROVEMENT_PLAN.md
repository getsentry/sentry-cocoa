# SentryCrash: Improvement Plan

## About This Document

A phased plan for improving SentryCrash: isolation, test coverage, architecture, documentation, and bug fixes. For the current-state analysis, see [SENTRYCRASH.md](SENTRYCRASH.md).

### Updating This Document

This document was generated with Claude using the prompt below. To refresh it, run the same prompt against the current codebase:

> Review the current state of `Sources/SentryCrash/` and the analysis in `develop-docs/SENTRYCRASH.md`. Produce an improvement plan covering: Phase 1 (isolation — public API surface, coupling analysis, recommendations), Phase 2 (test coverage — current state, well-tested vs untested components, recommendations), Phase 3 (architecture — internal structure issues, recommendations), Phase 4 (documentation), and Phase 5 (bug fixes — recently fixed, open issues from code TODOs, open GitHub issues). Cross-reference all claims against the actual source code.

## Table of Contents

- [Phase 1: Isolation (Public API)](#phase-1-isolation-public-api)
- [Phase 2: Confidence (Test Coverage)](#phase-2-confidence-test-coverage)
- [Phase 3: Architecture (Internal Structure)](#phase-3-architecture-internal-structure)
- [Phase 4: Documentation & Knowledge Sharing](#phase-4-documentation--knowledge-sharing)
- [Phase 5: Fix the Bugs](#phase-5-fix-the-bugs)

---

## Phase 1: Isolation (Public API)

### Coupling Analysis

**SDK → SentryCrash** (34 non-SentryCrash files import SentryCrash headers):

- `SentryClient.m`, `SentrySDKInternal.m`, `SentryCrashReportConverter.m`, `SentryCrashReportSink.m`
- `SentryCrashScopeObserver.m`, `SentryDefaultThreadInspector.m`, `SentryDefaultAppStateManager.m`
- `SentrySpanInternal.m`, `SentrySessionReplaySyncC.c`, plus ~25 more

**SentryCrash → SDK** (16 SentryCrash files import SDK headers):

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

**Test file location**: `Tests/SentryTests/SentryCrash/` (55 files)

| Category               | Count | Examples                                                              |
| ---------------------- | ----- | --------------------------------------------------------------------- |
| ObjC tests (.m)        | 31    | `SentryCrashJSONCodec_Tests.m`, `SentryCrashObjC_Tests.m`             |
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

| File                                      | Lines | Risk   | Notes                                                                 |
| ----------------------------------------- | ----- | ------ | --------------------------------------------------------------------- |
| `SentryCrashC.c`                          | 317   | HIGH   | Main C API entry point. Only tested indirectly via integration tests. |
| `SentryCrashReport.c`                     | 1795  | HIGH   | Report writing logic. Only tested indirectly via report store tests.  |
| `SentryCrashMonitor_MachException.c`      | ~600  | HIGH   | Mach exception handling. No direct tests (hard to test safely).       |
| `SentryCrashCachedData.c`                 | ~360  | HIGH   | Thread caching with recent race fix. No direct tests.                 |
| `SentryCrashMemory.c`                     | ~140  | MEDIUM | Memory reading utilities. No tests.                                   |
| `SentryCrashStackCursor.c`                | ~60   | MEDIUM | Base stack walker. Only self-thread variant tested.                   |
| `SentryCrashStackCursor_Backtrace.c`      | ~60   | MEDIUM | Backtrace-based walking. No tests.                                    |
| `SentryCrashStackCursor_MachineContext.c` | ~135  | MEDIUM | Machine context walking. No tests.                                    |

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

The `Recording/Tools/` directory contains **~56% of all SentryCrash code** (11,872 lines across 20+ files) with no further organization. Files range from CPU-specific register handling to JSON encoding to ObjC runtime introspection.

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

1. **[SENTRYCRASH.md](SENTRYCRASH.md)** serves as the starting knowledge base
2. **Create architecture diagrams** showing:
   - Monitor system flow (crash detection → report writing → next-launch recovery)
   - Data flow between SDK and SentryCrash
   - Thread model (which threads run what code during/after crash)
3. **Document signal-safety rules**: What functions can be called in crash context, and why
4. **Create onboarding guide**: Step-by-step for new team members to understand SentryCrash
5. **Document Sentry-specific modifications**: Maintain a clear list of what's been added/changed vs upstream KSCrash (see [Sentry-Specific Additions](SENTRYCRASH.md#sentry-specific-additions-not-in-kscrash))

---

## Phase 5: Fix the Bugs

### Recently Fixed (for reference)

| Date         | Issue                                                   | Commit      |
| ------------ | ------------------------------------------------------- | ----------- |
| Feb 20, 2026 | Data race in `SentryCrashCachedData.c` (EXC_BAD_ACCESS) | `80963bd21` |
| Feb 17, 2026 | Concurrent crashes misidentified as recrash             | `bcabca0bb` |
| Feb 3, 2026  | NSException stack cursor implementation                 | `c9fc5beba` |
| Oct 2025     | Crashed thread missing from thread list                 | `b115f8270` |
| Oct 2025     | Thread deallocation issues                              | `f4f94f525` |
| Sept 2025    | App launch hang caused by SDK                           | `ea12acf4a` |
| Nov 2025     | Remove symbolication causing deadlocks                  | `cd6b26bd1` |

### Open Issues to Address

| Priority | Issue                                   | Location                                          | Description                                          |
| -------- | --------------------------------------- | ------------------------------------------------- | ---------------------------------------------------- |
| MEDIUM   | NSDictionary introspection broken       | `SentryCrashObjC.c:1816`                          | `sentrycrashobjc_dictionaryCount()` always returns 0 |
| MEDIUM   | CPU arch detection returns NULL         | `SentryCrashCPU.c:42`                             | `NXGetLocalArchInfo()` blocked by App Store          |
| MEDIUM   | Mach exception freeze workaround        | `SentryCrashMonitor_MachException.c:338`          | Unclear if secondary thread fires                    |
| MEDIUM   | Unimplemented report introspection      | `SentryCrashReport.c:653`                         | NSDictionary/NSException cases not implemented       |
| LOW      | Thread-local storage for C++ exceptions | `SentryCrashMonitor_CPPException.cpp:71`          | Global cursor, potential concurrent issue            |
| LOW      | SentryDevice API consolidation          | `SentryCrashMonitor_System.m:406,531`             | Duplicate device info collection                     |
| LOW      | Deprecated 32-bit platform code         | `SentryCrashCPU_arm.c`, `SentryCrashCPU_x86_32.c` | Dead code, maintenance burden                        |

### Open GitHub Issues

User-reported and team-tracked bugs from the [sentry-cocoa issue tracker](https://github.com/getsentry/sentry-cocoa/issues), organized by severity.

**HIGH priority (active user-facing bugs):**

| Issue                                                          | Description                                                                                                              |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| [#7298](https://github.com/getsentry/sentry-cocoa/issues/7298) | "Application Specific Information" contains random memory contents (PII risk, bad pointer arithmetic in report writing)  |
| [#4904](https://github.com/getsentry/sentry-cocoa/issues/4904) | Different main thread ID for errors vs traces (crash reports hardcode thread ID 0 in `SentryCrashReportConverter.m:268`) |
| [#6405](https://github.com/getsentry/sentry-cocoa/issues/6405) | Empty view hierarchy file sent during fatal crashes (best-effort capture produces empty JSON)                            |

**MEDIUM priority (correctness and architecture):**

| Issue                                                          | Description                                                                                                |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| [#4725](https://github.com/getsentry/sentry-cocoa/issues/4725) | Mach exception handling interferes with other SDKs' signal handlers (handler chaining issue)               |
| [#1589](https://github.com/getsentry/sentry-cocoa/issues/1589) | `SentryCrashMonitor_MachException` crashes on macOS in `handleExceptions()` at `mach_msg`                  |
| [#1562](https://github.com/getsentry/sentry-cocoa/issues/1562) | C++ exception stack traces show only `CPPExceptionTerminate`, not structured frames                        |
| [#6180](https://github.com/getsentry/sentry-cocoa/issues/6180) | `cpu_type` and `cpu_subtype` missing from reports (removed to fix hang, needs background-thread retrieval) |
| [#6116](https://github.com/getsentry/sentry-cocoa/issues/6116) | `testWriteCrashReport_ContainsCrashInfoMessage` disabled on iOS 26+, needs revisiting                      |

**LOW priority (features and tech debt):**

| Issue                                                          | Description                                                                              |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [#7501](https://github.com/getsentry/sentry-cocoa/issues/7501) | Expose public option to disable memory introspection (privacy, related to #7298)         |
| [#900](https://github.com/getsentry/sentry-cocoa/issues/900)   | Revisit `NXGetLocalArchInfo` for device architecture (Firebase never had issues with it) |
| [#2747](https://github.com/getsentry/sentry-cocoa/issues/2747) | Support unhandled exceptions on watchOS                                                  |
| [#1923](https://github.com/getsentry/sentry-cocoa/issues/1923) | Increase max stacktrace frame length beyond 100                                          |
| [#6699](https://github.com/getsentry/sentry-cocoa/issues/6699) | Evaluate `-fstack-protector-all` compiler flag                                           |

**Cross-cutting themes:**

- **Memory safety in crash reports** — [#7298](https://github.com/getsentry/sentry-cocoa/issues/7298), [#7501](https://github.com/getsentry/sentry-cocoa/issues/7501), and [#6699](https://github.com/getsentry/sentry-cocoa/issues/6699) form a privacy/safety cluster around memory introspection during crash writing.
