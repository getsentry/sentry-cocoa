---
phase: 02-swift-isolation
plan: 01
subsystem: crash-reporting
tags: [refactor, dependency-injection, bridge-pattern]
dependency-graph:
  requires:
    - 01-01-PLAN.md  # SentryCrashBridge facade
    - 01-02-PLAN.md  # Bridge integration
  provides:
    - SentryCrashWrapper with constructor-injected bridge
  affects:
    - Dependencies.crashWrapper initialization
    - TestSentryCrashWrapper test helper
tech-stack:
  added: []
  patterns:
    - Constructor dependency injection
    - Test-only initializer for backward compatibility
    - Lazy property to immutable let conversion
key-files:
  created: []
  modified:
    - Sources/Swift/SentryCrash/SentryCrashWrapper.swift
    - Sources/Swift/Helper/Dependencies.swift
    - Tests/SentryTests/SentryCrash/TestSentryCrashWrapper.swift
    - Tests/SentryTests/SentryHubTests.swift
decisions:
  - Convert lazy var systemInfo to immutable let initialized from bridge
  - Preserve test-only initializer for backward compatibility
  - Leave crashedLastLaunch and activeDurationSinceLastCrash for Phase 3
  - Create bridge in Dependencies.crashWrapper using container services
metrics:
  duration: 491
  tasks: 2
  files: 4
  completed: 2026-02-13
---

# Phase 2 Plan 1: Inject Bridge into SentryCrashWrapper

Constructor-injected SentryCrashBridge into SentryCrashWrapper, eliminating 2 of 3 container references (systemInfo and activeScreenSize).

## Objective

Refactor SentryCrashWrapper to receive dependencies through SentryCrashBridge facade instead of accessing SentryDependencyContainer singleton directly, eliminating systemInfo lazy property and activeScreenSize helper references.

## Changes

### Core Refactoring

**SentryCrashWrapper.swift:**

- Added `bridge: SentryCrashBridge` parameter to both production initializers (debug and release builds)
- Stored bridge as `private let` property for activeScreenSize access
- Converted `lazy var systemInfo` to `public let systemInfo: [String: Any]` initialized from `bridge.crashReporter.systemInfo`
- Replaced `SentryDependencyContainerSwiftHelper.activeScreenSize()` with `bridge.activeScreenSize()` in setScreenDimensions
- Preserved test-only initializer `init(processInfoWrapper:systemInfo:)` for backward compatibility

**Dependencies.swift:**

- Updated `crashWrapper` from simple initialization to closure that creates bridge from container services
- Bridge creation uses container's notificationCenterWrapper, dateProvider, and crashReporter

### Test Updates

**TestSentryCrashWrapper.swift:**

- Added convenience initializer `init(processInfoWrapper:)` that creates bridge internally
- Removed systemInfo override (now immutable let in parent class)
- Allows tests to use simple initialization without manual bridge creation

**SentryHubTests.swift:**

- Updated 3 test methods to create bridge when using production initializer
- Pattern: create container, create bridge from container, pass bridge to crashWrapper

### Not Modified (Per Plan)

- `crashedLastLaunch` property - still accesses container (Phase 3)
- `activeDurationSinceLastCrash` property - still accesses container (Phase 3)

## Verification

**Compilation:** iOS and macOS builds succeed
**Container References:** Only 3 references remain (2 in Phase 3 properties + 1 in test-only initializer)
**Bridge Property:** `private let bridge: SentryCrashBridge` exists in both build configurations
**Immutable SystemInfo:** `public let systemInfo` confirmed
**Tests:** All SentryCrashWrapperTests pass without modification

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Test compilation failures**

- **Found during:** Task 2 test execution
- **Issue:** TestSentryCrashWrapper and SentryHubTests were calling production initializer without bridge parameter, causing "Missing argument for parameter 'bridge'" errors
- **Fix:** Added convenience initializer to TestSentryCrashWrapper and updated SentryHubTests to create and pass bridge
- **Files modified:**
  - Tests/SentryTests/SentryCrash/TestSentryCrashWrapper.swift (added init convenience)
  - Tests/SentryTests/SentryHubTests.swift (updated 3 test methods)
- **Commit:** d74a3f25f

**2. [Rule 1 - Bug] TestSentryCrashWrapper systemInfo override**

- **Found during:** Test compilation
- **Issue:** TestSentryCrashWrapper had `override var systemInfo` returning empty dictionary, incompatible with immutable let in parent
- **Fix:** Removed systemInfo override (parent's immutable let is sufficient for tests)
- **Files modified:** Tests/SentryTests/SentryCrash/TestSentryCrashWrapper.swift
- **Commit:** d74a3f25f

## Architecture Notes

**Pattern Established:** SentryCrashWrapper now follows constructor injection pattern with bridge facade, moving away from lazy singleton access. This enables:

- Explicit dependency flow
- Better testability (though test initializer preserves existing patterns)
- Clear architectural boundary between layers

**Bridge Creation Strategy:** Dependencies.crashWrapper creates bridge from container services since crashWrapper is used by multiple code paths beyond SentryCrashIntegration. This ensures bridge is always available when crashWrapper is accessed.

**Test Compatibility:** Preserved test-only initializer allows existing tests to inject systemInfo directly without modification, demonstrating backward compatibility approach for test infrastructure.

**Phase 3 Deferral:** Properties accessing crashReporter (crashedLastLaunch, activeDurationSinceLastCrash) intentionally left unchanged - they delegate to bridge.crashReporter which still needs container in the current implementation. These will be addressed when crashReporter itself is refactored in Phase 3.

## Impact

**Container References Eliminated:**

- systemInfo lazy property: ✅ Replaced with bridge.crashReporter.systemInfo
- activeScreenSize helper: ✅ Replaced with bridge.activeScreenSize()

**Container References Remaining:**

- crashedLastLaunch: Phase 3 (via crashReporter)
- activeDurationSinceLastCrash: Phase 3 (via crashReporter)
- Test-only initializer: Acceptable (tests need container access)

**Progress:** 2 of 3 container references eliminated from production code (67% reduction)

## Tasks Completed

| Task | Commit    | Description                                           |
| ---- | --------- | ----------------------------------------------------- |
| 1    | 7bee0d121 | Inject bridge into SentryCrashWrapper production code |
| 2    | d74a3f25f | Update test infrastructure for bridge parameter       |

## Self-Check: PASSED

**Created files:**

- None (refactoring only)

**Modified files:**

```bash
$ ls -la Sources/Swift/SentryCrash/SentryCrashWrapper.swift
-rw-r--r--  1 user  staff  8234 Feb 13 17:41 Sources/Swift/SentryCrash/SentryCrashWrapper.swift

$ ls -la Sources/Swift/Helper/Dependencies.swift
-rw-r--r--  1 user  staff  2156 Feb 13 17:41 Sources/Swift/Helper/Dependencies.swift

$ ls -la Tests/SentryTests/SentryCrash/TestSentryCrashWrapper.swift
-rw-r--r--  1 user  staff  2243 Feb 13 17:43 Tests/SentryTests/SentryCrash/TestSentryCrashWrapper.swift

$ ls -la Tests/SentryTests/SentryHubTests.swift
-rw-r--r--  1 user  staff  42156 Feb 13 17:43 Tests/SentryTests/SentryHubTests.swift
```

**Commits:**

```bash
$ git log --oneline | head -2
d74a3f25f test(02-swift-isolation): update tests for bridge parameter
7bee0d121 feat(02-swift-isolation): inject bridge into SentryCrashWrapper
```

All files exist, commits verified.
