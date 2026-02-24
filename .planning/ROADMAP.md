# Roadmap: SentryCrash Isolation

## Overview

This roadmap delivers complete isolation of SentryCrash from SentryDependencyContainer through a concrete facade pattern. We'll design and implement an SDK-side bridge class, migrate all Swift and Objective-C call sites to use the facade, validate zero remaining container references through grep and test execution, and document the architectural boundary for future maintainers.

## Phases

- [x] **Phase 1: Facade Design & Implementation** - Create SDK-side bridge class that provides all services SentryCrash needs
- [x] **Phase 2: Swift Isolation** - Remove container references from Swift SentryCrash files
- [x] **Phase 3: ObjC Isolation** - Remove container references from Objective-C SentryCrash files
- [ ] **Phase 4: Verification** - Validate complete isolation through tests and grep checks
- [ ] **Phase 5: Documentation** - Document facade pattern and architectural boundary

## Phase Details

### Phase 1: Facade Design & Implementation

**Goal**: SDK provides a concrete bridge class that SentryCrash can consume for all its service dependencies
**Depends on**: Nothing (first phase)
**Requirements**: FACADE-01, FACADE-02, FACADE-03
**Plans**: 2 plans in 2 waves

**Success Criteria** (what must be TRUE):

1. `SentryCrashBridge` class exists in SDK-side code (Sources/Swift or Sources/Sentry)
2. Facade exposes all five services SentryCrash needs: notificationCenterWrapper, dateProvider, crashReporter, uncaughtExceptionHandler, activeScreenSize
3. Facade is marked `@objc` and accessible from both Swift and Objective-C code
4. SDK initialization path configures and provides the facade instance before SentryCrash installation

Plans:

- [x] 01-01-PLAN.md — Create SentryCrashBridge facade class with all five service properties
- [x] 01-02-PLAN.md — Integrate bridge into SentryCrashIntegration initialization flow

### Phase 2: Swift Isolation

**Goal**: Swift SentryCrash files consume dependencies through the facade, not SentryDependencyContainer
**Depends on**: Phase 1
**Requirements**: SWIFT-01, SWIFT-02
**Plans**: 2 plans in 1 wave

**Success Criteria** (what must be TRUE):

1. `SentryCrashWrapper.swift` imports only necessary modules, not `SentryDependencyContainer`
2. `SentryCrashWrapper.swift` receives systemInfo and activeScreenSize from facade, not container (2 accesses eliminated)
3. `SentryCrashIntegrationSessionHandler.swift` receives dateProvider from facade, not container (1 access eliminated)
4. All SentryCrashWrapper tests pass without modification (or with minimal fixture updates for facade injection)

Plans:

- [x] 02-01-PLAN.md — Refactor SentryCrashWrapper to use bridge for systemInfo and activeScreenSize
- [x] 02-02-PLAN.md — Refactor SentryCrashIntegrationSessionHandler to use bridge for dateProvider

### Phase 3: ObjC Isolation

**Goal**: Objective-C SentryCrash files consume dependencies through the facade, not SentryDependencyContainer
**Depends on**: Phase 2
**Requirements**: OBJC-01, OBJC-02, OBJC-03
**Plans**: 3 plans in 1 wave

**Success Criteria** (what must be TRUE):

1. `SentryCrash.m` imports Sentry-Swift.h and uses bridge.notificationCenterWrapper (4 accesses eliminated)
2. `SentryCrashInstallation.m` imports Sentry-Swift.h and uses bridge.crashReporter (4 accesses eliminated)
3. `SentryCrashWrapper.swift` uses bridge for crashedLastLaunch and activeDurationSinceLastCrash (2 remaining accesses eliminated)
4. All SentryCrash integration tests pass
5. Fallback patterns preserve compatibility when bridge not set

Plans:

- [x] 03-01-PLAN.md — Inject bridge into SentryCrash.m (4 notificationCenterWrapper refs) and SentryCrashMonitor_NSException.m (1 uncaughtExceptionHandler ref)
- [x] 03-02-PLAN.md — Inject bridge into SentryCrashInstallation.m for crashReporter access (4 refs eliminated)
- [x] 03-03-PLAN.md — Complete SentryCrashWrapper isolation (2 remaining refs eliminated)

### Phase 4: Verification

**Goal**: Zero container references remain in SentryCrash code and all existing functionality is preserved
**Depends on**: Phase 3
**Requirements**: VERIFY-01, VERIFY-02, VERIFY-03
**Plans**: 1 plan

**Success Criteria** (what must be TRUE):

1. All existing SentryCrash unit tests pass (SentryCrashWrapper, SentryCrash, SentryCrashInstallation tests)
2. `grep -r "SentryDependencyContainer" Sources/SentryCrash/` returns zero results
3. `grep -r "SentryDependencyContainer" Sources/Swift/SentryCrash/` returns zero results (no Swift SentryCrash files reference container)
4. Multi-platform builds succeed (iOS, macOS, tvOS)

Plans:

- [ ] 04-01-PLAN.md — Run SentryCrash test suite and verify zero container references

### Phase 5: Documentation

**Goal**: Facade pattern and SentryCrash architectural boundary are documented for future maintainers
**Depends on**: Phase 4
**Requirements**: DOCS-01
**Success Criteria** (what must be TRUE):

1. `develop-docs/SENTRYCRASH.md` exists and describes the facade pattern
2. Documentation explains why SentryCrash must not directly access SentryDependencyContainer
3. Documentation lists the five services provided through the facade
4. Documentation provides guidance for adding new SentryCrash dependencies (use facade, not container)
   **Plans**: TBD

Plans:

- [ ] 05-01: TBD

## Progress

| Phase                             | Plans Complete | Status      | Completed  |
| --------------------------------- | -------------- | ----------- | ---------- |
| 1. Facade Design & Implementation | 2/2            | ✓ Complete  | 2026-02-13 |
| 2. Swift Isolation                | 2/2            | ✓ Complete  | 2026-02-13 |
| 3. ObjC Isolation                 | 3/3            | ✓ Complete  | 2026-02-13 |
| 4. Verification                   | 0/1            | Not started | -          |
| 5. Documentation                  | 0/0            | Not started | -          |
