---
phase: 03-objc-isolation
plan: 01
subsystem: crash-reporting
tags: [objective-c, dependency-injection, bridge-pattern, crash-handler]

# Dependency graph
requires:
  - phase: 01-facade-design-implementation
    provides: SentryCrashBridge facade class for SDK services
  - phase: 02-swift-isolation
    provides: Bridge injection into Swift crash wrapper and session handler
provides:
  - Bridge property injection into SentryCrash and NSException monitor
  - Elimination of 5 direct SentryDependencyContainer references (4 in SentryCrash.m, 1 in NSException monitor)
  - Fallback pattern for backward compatibility
affects: [04-objc-c-removal, testing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - KVC-based bridge injection in Swift wrapper to bypass compile-time type issues
    - Static bridge variable pattern in C-style monitor code
    - NS_ASSUME_NONNULL audit regions for nullability consistency
    - __OBJC__ conditional compilation guards for C/ObjC interop

key-files:
  created: []
  modified:
    - Sources/Sentry/include/SentryCrash.h
    - Sources/SentryCrash/Recording/SentryCrash.m
    - Sources/Swift/SentryCrash/SentryCrashSwift.swift
    - Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_NSException.h
    - Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_NSException.m
    - Sources/Swift/Integrations/SentryCrash/SentryCrashIntegration.swift

key-decisions:
  - "Use KVC (setValue:forKey:) in SentryCrashSwift.setBridge instead of direct property access to avoid Swift/ObjC type visibility issues during compilation"
  - "Add NS_ASSUME_NONNULL_BEGIN/END to SentryCrash.h to satisfy nullability requirements triggered by adding nullable bridge property"
  - "Mark previously implicitly-nullable properties explicitly (userInfo, sink, onCrash, doNotIntrospectClasses, uncaughtExceptionHandler, basePath init param)"
  - "Use static variable pattern for bridge in NSException monitor since setEnabled is a C function without object context"
  - "Wrap ObjC-specific bridge code in __OBJC__ guards for C header compatibility"

patterns-established:
  - "Bridge property injection with fallback pattern: `self.bridge ? self.bridge.service : Container.sharedInstance.service`"
  - "Static bridge reference for C-style monitor code with setter function"
  - "Bridge set during install() phase, before monitor activation"

# Metrics
duration: 18.1min
completed: 2026-02-13
---

# Phase 03 Plan 01: Objective-C Isolation Summary

**Bridge injection into SentryCrash.m and NSException monitor eliminates 5 container references with fallback compatibility**

## Performance

- **Duration:** 18.1 min (1084 seconds)
- **Started:** 2026-02-13T21:30:44Z
- **Completed:** 2026-02-13T21:48:48Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Added bridge property to SentryCrash with NS_ASSUME_NONNULL nullability audit
- Injected bridge from SentryCrashIntegration through SentryCrashSwift to SentryCrash.m
- Eliminated 5 direct container references (4 notificationCenterWrapper + 1 uncaughtExceptionHandler)
- All references now use bridge when available, fallback to container for compatibility

## Task Commits

Each task was committed atomically:

1. **Task 1: Add bridge property to SentryCrash and inject via SentryCrashSwift** - `cf459712c` (feat)
   - Added SentryCrashBridge property to SentryCrash.h with forward declaration
   - Added NS_ASSUME_NONNULL_BEGIN/END for nullability audit
   - Updated SentryCrash.m to use bridge.notificationCenterWrapper with fallback (4 references)
   - Added setBridge method to SentryCrashSwift.swift using KVC

2. **Task 2: Wire bridge from SentryCrashIntegration through SentryCrashSwift to SentryCrash** - `9cd83321f` (feat)
   - Call crashReporter.setBridge(bridge) in SentryCrashIntegration init
   - Bridge set before crash handler installation ensuring proper initialization order

3. **Task 3: Eliminate container reference in SentryCrashMonitor_NSException.m** - `d59ab2ad0` (feat)
   - Added sentrycrashcm_nsexception_setBridge function for static bridge storage
   - Updated setEnabled to use g_bridge.crashReporter.uncaughtExceptionHandler with fallback
   - Called setBridge from SentryCrash.m install method

## Files Created/Modified

- `Sources/Sentry/include/SentryCrash.h` - Added bridge property, forward declaration, nullability audit
- `Sources/SentryCrash/Recording/SentryCrash.m` - Use bridge for notifications, call NSException bridge setter
- `Sources/Swift/SentryCrash/SentryCrashSwift.swift` - Add setBridge method using KVC, fix userInfo nil handling
- `Sources/Swift/Integrations/SentryCrash/SentryCrashIntegration.swift` - Inject bridge into crash reporter
- `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_NSException.h` - Declare bridge setter with **OBJC** guards
- `Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_NSException.m` - Static bridge storage and usage

## Decisions Made

### KVC for Bridge Property Access in Swift

- **Context:** When compiling SentryCrashSwift.swift, direct property access `sentryCrash.bridge = bridge` failed because Swift couldn't see the bridge property on the ObjC SentryCrash class during compilation (circular dependency: Swift needs SentryCrashBridge which is Swift, ObjC header references it via forward declaration)
- **Decision:** Use KVC: `sentryCrash.setValue(bridge, forKey: "bridge")` to bypass compile-time type checking
- **Rationale:** Property exists at runtime (ObjC has it), KVC works with id types, avoids complex module ordering issues

### NS_ASSUME_NONNULL Nullability Audit

- **Context:** Adding `nullable` bridge property triggered compiler requirement for explicit nullability on all pointers in SentryCrash.h
- **Decision:** Wrap @interface in NS_ASSUME_NONNULL_BEGIN/END and mark nullable properties explicitly
- **Rationale:** Standard Cocoa pattern, fixes nullability warnings, makes Swift interop cleaner

### Static Bridge Pattern for C Functions

- **Context:** NSException monitor's setEnabled is a static C function with no object context, can't use property injection
- **Decision:** Static variable `g_bridge` with setter function `sentrycrashcm_nsexception_setBridge`
- **Rationale:** Standard pattern in SentryCrash's C-style monitor code, bridge is set during setup (safe), not accessed in signal handlers

### Fallback to Container Pattern

- **Context:** Bridge may not be set in tests or early initialization
- **Decision:** All bridge accesses use ternary: `self.bridge ? self.bridge.service : Container.sharedInstance.service`
- **Rationale:** Preserves backward compatibility, graceful degradation, no test breakage

### **OBJC** Guards in C Header

- **Context:** NSException monitor header is C, but bridge setter needs ObjC types (SentryCrashBridge *)
- **Decision:** Wrap @class forward declaration and bridge setter in `#ifdef __OBJC__`
- **Rationale:** Header remains valid C, ObjC code sees bridge function, no compilation errors

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed Swift compilation errors from nullability changes**

- **Found during:** Task 1 (after adding NS_ASSUME_NONNULL)
- **Issue:** NS_ASSUME_NONNULL changed basePath init parameter and userInfo property from implicitly nullable to nonnull, breaking Swift wrapper expectations
- **Fix:** Marked basePath init param as `nullable`, fixed userInfo getter to return `??[:]` for nil
- **Files modified:** Sources/Sentry/include/SentryCrash.h, Sources/Swift/SentryCrash/SentryCrashSwift.swift
- **Verification:** iOS and macOS builds succeed
- **Committed in:** cf459712c (Task 1 commit)

**2. [Rule 3 - Blocking] Added _Nonnull to C function return type**

- **Found during:** Task 3 (NSException monitor compilation)
- **Issue:** sentrycrashcm_nsexception_getAPI return type missing nullability specifier after NS_ASSUME_NONNULL in parent headers
- **Fix:** Added `_Nonnull` to function return type: `SentryCrashMonitorAPI *_Nonnull sentrycrashcm_nsexception_getAPI(void)`
- **Files modified:** Sources/SentryCrash/Recording/Monitors/SentryCrashMonitor_NSException.h
- **Verification:** iOS build succeeds
- **Committed in:** d59ab2ad0 (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both auto-fixes necessary for compilation. No scope creep - resolved issues caused by nullability audit requirements.

## Issues Encountered

### Swift Can't See Bridge Property at Compile Time

- **Problem:** Direct property access in Swift failed: "value of type 'SentryCrash' has no member 'bridge'"
- **Root cause:** Circular dependency - SentryCrash.h references SentryCrashBridge (Swift) via forward declaration, Swift sees incomplete type during compilation
- **Solution:** Use KVC `setValue(_:forKey:)` which works with runtime typing
- **Result:** Compiles cleanly, property access works at runtime

### Nullability Cascade from Single Property

- **Problem:** Adding one nullable property triggered nullability requirement for entire header
- **Root cause:** Once any nullability annotation appears, Clang requires all pointers be annotated (completeness checking)
- **Solution:** Applied NS_ASSUME_NONNULL pattern with explicit nullable overrides where needed
- **Result:** Clean nullability audit, better Swift interop

## Next Phase Readiness

- 5 container references eliminated from core Objective-C crash recording code
- Bridge propagation complete through entire initialization chain
- Fallback pattern ensures no test breakage
- Ready for remaining Objective-C container elimination phases
- Pattern established for future C-style monitor bridge injection

---

_Phase: 03-objc-isolation_
_Completed: 2026-02-13_

## Self-Check: PASSED

All files and commits verified to exist:

- ✓ 6 modified files present
- ✓ 3 task commits (cf459712c, 9cd83321f, d59ab2ad0)
- ✓ iOS and macOS builds succeed
