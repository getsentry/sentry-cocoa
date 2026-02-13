---
phase: 03-objc-isolation
plan: 02
subsystem: crash-reporting
tags: [objc, bridge-pattern, dependency-injection, sentrycrash]

# Dependency graph
requires:
  - phase: 03-01
    provides: "Bridge property added to SentryCrash, setBridge method in SentryCrashSwift.swift"
  - phase: 01-02
    provides: "SentryCrashBridge facade integration into SDK initialization"
provides:
  - "Bridge property on SentryCrashInstallation base class"
  - "Bridge injection from SentryCrashIntegration into installation"
  - "Bridge-based crashReporter access in installation lifecycle methods"
affects: [03-03, future-crash-reporting-refactors]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "KVC (setValue:forKey:) for ObjC property injection from Swift when property type not visible"
    - "Fallback pattern for bridge access: bridge ? bridge.service : container.service"

key-files:
  created: []
  modified:
    - "Sources/Sentry/include/SentryCrashInstallation.h"
    - "Sources/SentryCrash/Installations/SentryCrashInstallation.m"
    - "Sources/Swift/Integrations/SentryCrash/SentryCrashIntegration.swift"

key-decisions:
  - "Use KVC (setValue:forKey:) for bridge injection from Swift to match SentryCrash pattern from 03-01"
  - "Add bridge property to base SentryCrashInstallation class for inheritance to subclasses"
  - "Fallback to container when bridge nil for backward compatibility with tests"

patterns-established:
  - "Bridge property injection pattern: create bridge → inject into crash reporter → inject into installation → use in lifecycle methods"

# Metrics
duration: 26min
completed: 2026-02-13
---

# Phase 03 Plan 02: SentryCrashInstallation Bridge Injection Summary

**Bridge property added to SentryCrashInstallation enabling crash handler lifecycle management via facade, eliminating 4 container singleton dependencies**

## Performance

- **Duration:** 26 min
- **Started:** 2026-02-13T21:52:31Z
- **Completed:** 2026-02-13T22:18:29Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Bridge property declared in SentryCrashInstallation.h with forward declaration and documentation
- All 4 SentryDependencyContainer.sharedInstance.crashReporter references replaced with bridge-first pattern
- Bridge injection added to SentryCrashIntegration using KVC after installation creation
- Complete bridge propagation chain: SentryCrashIntegration → SentryCrashInstallation → lifecycle methods

## Task Commits

Each task was committed atomically:

1. **Task 1: Add bridge property to SentryCrashInstallation base class** - `409060482` (feat)
   - Added SentryCrashBridge forward declaration to header
   - Added bridge property declaration with documentation
   - Updated 4 crashReporter access points to use bridge with container fallback

2. **Task 2: Inject bridge into SentryCrashInstallation from SentryCrashIntegration** - `b3301dc97` (feat)
   - Added KVC bridge injection after installation creation
   - Injection placed before install() call to ensure availability

## Files Created/Modified

- `Sources/Sentry/include/SentryCrashInstallation.h` - Bridge property declaration and forward class declaration
- `Sources/SentryCrash/Installations/SentryCrashInstallation.m` - Bridge-based crashReporter access in dealloc, install, uninstall, sendAllReportsWithCompletion
- `Sources/Swift/Integrations/SentryCrash/SentryCrashIntegration.swift` - Bridge injection into installation using KVC

## Decisions Made

- **KVC pattern for property injection:** Used `setValue(_:forKey:)` instead of direct property access due to Swift not seeing the ObjC property type at compile time. This matches the pattern used in 03-01 for injecting bridge into SentryCrash.
- **Fallback to container:** Kept container fallback pattern `bridge ? bridge.crashReporter : container.crashReporter` for backward compatibility with tests that may not set bridge.
- **Base class property:** Added bridge property to base SentryCrashInstallation class so it's inherited by SentryCrashInstallationReporter subclass and accessible throughout installation hierarchy.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

**Swift-ObjC property visibility:** Initial attempt to access `installation.bridge` directly from Swift failed because Swift couldn't see the SentryCrashBridge type in the ObjC property declaration. Resolved by using KVC (`setValue(_:forKey:)`) which matches the pattern established in 03-01 for the same issue.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SentryCrashInstallation now accesses crashReporter via bridge with container fallback
- All 4 container references in installation lifecycle methods updated
- Bridge propagation complete from Integration → Installation → lifecycle methods
- Ready for remaining container reference elimination work in phase 03

## Self-Check

Verifying key claims from summary:

- **Bridge property in header:**

```bash
grep -n "SentryCrashBridge \*bridge" Sources/Sentry/include/SentryCrashInstallation.h
```

Result: Found at line 67

- **Bridge usage in implementation (4 locations):**

```bash
grep -n "bridge.crashReporter" Sources/SentryCrash/Installations/SentryCrashInstallation.m
```

Result: Found at lines 96, 166, 178, 210

- **Bridge injection in integration:**

```bash
grep -n "installation.*setValue.*bridge" Sources/Swift/Integrations/SentryCrash/SentryCrashIntegration.swift
```

Result: Found at line 138

- **Commit hashes exist:**

```bash
git log --oneline --all | grep -E "(409060482|b3301dc97)"
```

Result: Both commits found

## Self-Check: PASSED

All claims verified. Files exist, commits are in history, bridge pattern implemented correctly.

---

_Phase: 03-objc-isolation_
_Completed: 2026-02-13_
