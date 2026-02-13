# Requirements: SentryCrash Isolation

**Defined:** 2026-02-13
**Core Value:** SentryCrash must have zero direct references to SentryDependencyContainer

## v1 Requirements

### Facade

- [ ] **FACADE-01**: SDK-side concrete class `SentryCrashBridge` provides all services SentryCrash needs from the SDK
- [ ] **FACADE-02**: Facade class is `@objc`-accessible so both Swift and ObjC SentryCrash code can consume it
- [ ] **FACADE-03**: SDK initializes and configures the facade before SentryCrash installation begins

### Swift Isolation

- [ ] **SWIFT-01**: `SentryCrashWrapper.swift` no longer imports or references `SentryDependencyContainer` (2 accesses: systemInfo, activeScreenSize)
- [ ] **SWIFT-02**: `SentryCrashIntegrationSessionHandler.swift` no longer imports or references `SentryDependencyContainer` (1 access: dateProvider)

### ObjC Isolation

- [ ] **OBJC-01**: `SentryCrash.m` no longer imports or references `SentryDependencyContainer` (4 accesses: notificationCenterWrapper)
- [ ] **OBJC-02**: `SentryCrashInstallation.m` no longer imports or references `SentryDependencyContainer` (3 accesses: crashReporter)
- [ ] **OBJC-03**: `SentryCrashMonitor_NSException.m` no longer imports or references `SentryDependencyContainer` (1 access: uncaughtExceptionHandler)

### Verification

- [ ] **VERIFY-01**: All existing SentryCrash unit tests pass without modification (or with minimal test fixture updates)
- [ ] **VERIFY-02**: `grep -r "SentryDependencyContainer" Sources/SentryCrash/` returns zero results
- [ ] **VERIFY-03**: `grep -r "SentryDependencyContainer" Sources/Swift/SentryCrash/` returns zero results (Swift SentryCrash files)

### Documentation

- [ ] **DOCS-01**: Facade pattern and SentryCrash boundary documented in `develop-docs/SENTRYCRASH.md`

## v2 Requirements

### Module Enforcement

- **MOD-01**: SentryCrash as separate build target that cannot import SentryDependencyContainer at compile time
- **MOD-02**: CI check that prevents new SentryDependencyContainer references in SentryCrash code

## Out of Scope

| Feature                        | Reason                                                 |
| ------------------------------ | ------------------------------------------------------ |
| Compile-time module separation | Deferred to v2 — runtime isolation sufficient for now  |
| SentryCrashWrapper refactoring | Only changing dependency flow, not the wrapper's API   |
| Public API changes             | Internal refactoring only, no external surface changes |
| Crash report format changes    | Isolation is structural, not behavioral                |
| CI enforcement                 | Deferred to v2 — grep verification sufficient for now  |

## Traceability

| Requirement | Phase   | Status  |
| ----------- | ------- | ------- |
| FACADE-01   | Phase 1 | Pending |
| FACADE-02   | Phase 1 | Pending |
| FACADE-03   | Phase 1 | Pending |
| SWIFT-01    | Phase 2 | Pending |
| SWIFT-02    | Phase 2 | Pending |
| OBJC-01     | Phase 3 | Pending |
| OBJC-02     | Phase 3 | Pending |
| OBJC-03     | Phase 3 | Pending |
| VERIFY-01   | Phase 4 | Pending |
| VERIFY-02   | Phase 4 | Pending |
| VERIFY-03   | Phase 4 | Pending |
| DOCS-01     | Phase 5 | Pending |

**Coverage:**

- v1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0

---

_Requirements defined: 2026-02-13_
_Last updated: 2026-02-13 after roadmap creation_
