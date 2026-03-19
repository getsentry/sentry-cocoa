# SentryCrash API Isolation

## What This Is

A refactoring project to decouple the Sentry SDK from SentryCrash by introducing a Swift protocol as the single API boundary. Currently 34 SDK files import SentryCrash headers directly — the goal is zero direct imports, with all interaction going through a well-defined protocol.

## Core Value

The SDK must never import SentryCrash headers directly — all crash reporter functionality is accessed through a Swift protocol, making SentryCrash a swappable implementation detail.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- ✓ SentryCrash captures native crashes (signal/Mach exceptions) — existing
- ✓ Crash reports are converted to Sentry events via SentryCrashReportConverter — existing
- ✓ SentryCrashWrapper exists as a partial Swift facade — existing
- ✓ Thread inspection works via SentryDefaultThreadInspector — existing
- ✓ Scope data syncs to C layer for crash-time access — existing
- ✓ Hub coordinates crash integration lifecycle (install/uninstall) — existing

### Active

- [ ] Define a Swift protocol (SentryCrashAPI or similar) covering all SentryCrash functionality the SDK needs
- [ ] Migrate all 34 SDK import sites to use the protocol instead of direct SentryCrash headers
- [ ] Ensure zero direct SentryCrash header imports from SDK source files
- [ ] Maintain all existing crash reporting behavior (signal handlers, Mach exceptions, report generation)
- [ ] Maintain all existing integrations (scope sync, session replay sync, transaction callbacks)
- [ ] Keep incremental — each migration step must leave the SDK fully functional and passing tests

### Out of Scope

- SentryCrash→SDK direction (16 files importing SDK headers) — separate future phase
- Internal SentryCrash architecture refactoring (Phase 3 of improvement plan)
- Test coverage improvements for SentryCrash internals (Phase 2 of improvement plan)
- Bug fixes within SentryCrash (Phase 5 of improvement plan)
- Removing or replacing SentryCrash entirely

## Context

- SentryCrash is a fork of KSCrash, independently evolved with Sentry-specific additions (scope sync, session replay sync, transaction callbacks)
- The improvement plan (`develop-docs/SENTRYCRASH_IMPROVEMENT_PLAN.md`) identifies coupling as the first priority
- Current coupling: 34 non-SentryCrash files import SentryCrash headers; 17+ distinct headers are imported
- `SentryCrashWrapper` already exists as a partial Swift facade but doesn't cover the full surface
- The codebase is hybrid ObjC/Swift with a protocol-oriented integration system already in place
- Signal-handler constraints mean some C-level interfaces must remain (async-signal-safe code can't call Swift)

## Constraints

- **Backward compatibility**: No public API changes — this is purely internal refactoring
- **Incremental migration**: Each commit must leave the SDK fully functional and all tests passing
- **Signal safety**: Crash-time code paths must remain async-signal-safe (C layer stays C)
- **Cross-platform**: Changes must work on all 5 Apple platforms (iOS, macOS, tvOS, watchOS, visionOS)
- **Hybrid SDK support**: PrivateSentrySDKOnly (SPI for React Native, Flutter, .NET, Unity) must continue to work

## Key Decisions

| Decision                                        | Rationale                                                                                        | Outcome   |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------ | --------- |
| Swift protocol (not ObjC @protocol or C facade) | Aligns with codebase direction toward Swift; protocol-oriented integration system already exists | — Pending |
| SDK→SentryCrash direction first                 | Higher impact (34 vs 16 import sites), clearer boundary to define                                | — Pending |
| Incremental migration                           | Lower risk, easier to review, each step independently verifiable                                 | — Pending |

---

_Last updated: 2026-03-19 after initialization_
