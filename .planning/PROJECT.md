# SentryCrash Isolation

## What This Is

A refactoring effort to decouple SentryCrash from the main Sentry Cocoa SDK by introducing a concrete facade class. SentryCrash currently reaches directly into `SentryDependencyContainer` for services like notification wrappers, date providers, and crash reporter state. This work creates a clean architectural boundary so SentryCrash receives its dependencies through a facade owned by the SDK side, rather than pulling them from the container.

## Core Value

SentryCrash must have zero direct references to `SentryDependencyContainer` — all dependencies flow through a single concrete facade class on the SDK side.

## Requirements

### Validated

- ✓ SentryCrash captures and reports crashes — existing
- ✓ SentryCrashWrapper provides testability facade — existing
- ✓ SentryCrashIntegration manages crash handler lifecycle — existing
- ✓ Higher-level components (SentryCrashIntegration, SentryCrashInstallationReporter) already use dependency injection — existing

### Active

- [ ] Remove all `SentryDependencyContainer` imports/references from SentryCrash code (Swift + ObjC, ~11 call sites)
- [ ] Create concrete facade class on SDK side that provides all services SentryCrash needs
- [ ] All existing SentryCrash tests pass after refactor
- [ ] Document the facade pattern and boundary in develop-docs

### Out of Scope

- Compile-time module enforcement — not doing target/module separation in this iteration
- Refactoring SentryCrashWrapper itself — only changing how it gets its dependencies
- Changing the public API surface of the SDK
- Modifying crash handling behavior or crash report format

## Context

**Current coupling (11 direct container accesses):**

Swift layer (~3 accesses):

- `SentryCrashWrapper.swift` — 2x accesses for `crashReporter.systemInfo` and `activeScreenSize()`
- `SentryCrashIntegrationSessionHandler.swift` — 1x access for `dateProvider`

ObjC core layer (~8 accesses):

- `SentryCrash.m` — 4x accesses for `notificationCenterWrapper`
- `SentryCrashInstallation.m` — 3x accesses for `crashReporter`
- `SentryCrashMonitor_NSException.m` — 1x access for `uncaughtExceptionHandler`

**Services SentryCrash needs from the SDK:**

1. `notificationCenterWrapper` — app lifecycle events
2. `dateProvider` — timestamps
3. `crashReporter` (SentryCrashSwift) — system info, crash state
4. `uncaughtExceptionHandler` — exception handler reference
5. `activeScreenSize` — device dimensions

**Existing good patterns to build on:**

- `SentryCrashIntegration` already uses dependency provider pattern
- `SentryCrashInstallationReporter` already uses dependency injection
- `SentryCrashReportSink` accesses SDK via Hub, not container

## Constraints

- **Compatibility**: Must compile on all platforms (iOS, macOS, tvOS, watchOS, visionOS)
- **Language bridge**: Facade must be accessible from both Swift and Objective-C SentryCrash code
- **Thread safety**: Crash handler context requires async-safe access patterns
- **Test coverage**: Existing test suite must continue to pass

## Key Decisions

| Decision                                                   | Rationale                                        | Outcome   |
| ---------------------------------------------------------- | ------------------------------------------------ | --------- |
| Concrete facade class (not protocol)                       | User preference — simpler, direct                | — Pending |
| Facade lives on SDK side (Sources/Swift or Sources/Sentry) | SDK owns the facade, SentryCrash receives it     | — Pending |
| Full isolation (Swift + ObjC)                              | Remove all ~11 container references, not partial | — Pending |

---

_Last updated: 2026-02-13 after initialization_
