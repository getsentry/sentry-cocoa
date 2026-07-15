# Plan: Convert `SentrySpotlightTransport` from ObjC to Swift

**Branch:** `ref/convert-spotlight-transport-to-swift`
**Status:** 🟡 In progress
**Goal:** Convert `Sources/Sentry/SentrySpotlightTransport.{h,m}` to a Swift class under
`Sources/Swift/Networking/`, following the patterns established by recent ObjC→Swift conversions.
Do **not** open a PR yet. Small commits, keep this file updated so work can be paused/resumed
and pushed at any point.

---

## Decisions (confirmed with user)

1. **Protocol conformance:** Try having the Swift class conform to the ObjC `SentryTransport`
   protocol **directly**. Expose `SentryTransport.h` + `SentryRequestManager.h` to the
   `_SentryPrivate` Swift module and **validate with a build immediately**. Fall back to a thin
   Swift protocol (like `TelemetryProcessorTransport`) only if the direct approach pulls in
   problematic ObjC dependencies / breaks the build.
2. **Unused `dispatchQueueWrapper`:** **Drop it.** It is stored but never used in the ObjC class.
   Removing it means updating the two call sites (`SentryTransportFactory.m` and the Swift test).

---

## Research summary

### Target

`Sources/Sentry/SentrySpotlightTransport.m` (~120 lines) + `include/SentrySpotlightTransport.h`.
Conforms to `SentryTransport`. Only `sendEnvelope:` has real logic:
filter envelope items to `event` + `transaction` types → build request via `requestBuilder`
→ send via `requestManager`. `storeEnvelope:` calls `sendEnvelope:`. `flush`, `recordLostEvent`
(both overloads), and `setStartFlushCallback` are intentionally empty.

### Dependencies already in Swift ✅

- `SentryEnvelope`, `SentryEnvelopeItem`, `SentryEnvelopeItemTypes` (`Sources/Swift/Tools/`, `Helper/`)
- `Options` / `SentryOptions` (`Sources/Swift/Options.swift`; has `spotlightUrl`, `enableSpotlight`)
- `SentryNSURLRequestBuilder` (`Sources/Swift/Networking/` — **closest template**)
- `SentryDispatchQueueWrapper` (`Sources/Swift/Helper/`) — being dropped anyway
- `SentryDataCategory` / `SentryDiscardReason` (reachable via mappers already in `SentryPrivate.h`)

### Dependencies still ObjC — NOT yet visible to Swift module ⚠️

- `SentryTransport` protocol (`NS_SWIFT_NAME(Transport)`, in `include/SentryTransport.h`) — **not** in `SentryPrivate.h`
- `SentryRequestManager` protocol (`NS_SWIFT_NAME(RequestManager)`, in `include/SentryRequestManager.h`) — **not** in `SentryPrivate.h`
- `SentryFlushResult` enum (defined in `SentryTransport.h`)
- `SentryRequestOperationFinished` block typedef (in `Public/SentryDefines.h`)

### Build system facts

- `Sources/Swift` is a `PBXFileSystemSynchronizedRootGroup` → new `.swift` files auto-discovered,
  **no `project.pbxproj` edit needed to add** the Swift file.
- `Sources/Sentry` uses **explicit** file references → deleting the `.m`/`.h` **requires editing
  `Sentry.xcodeproj/project.pbxproj`** (remove 5 references: 2 PBXBuildFile, 2 PBXFileReference,
  and the 2 group + 2 Sources-phase entries). Lines observed: 246, 645, 1250, 1251, 2027, 2028,
  4243, 4482. Precedent: PR #8099 (SentrySamplerDecision) edited pbxproj the same way.

### Callers / references

- `Sources/Sentry/SentryTransportFactory.m:38` — the only production instantiation.
- `Tests/SentryTests/Networking/SentrySpotlightTransportTests.swift` — already Swift, calls
  `SentrySpotlightTransport(options:requestManager:requestBuilder:dispatchQueueWrapper:)` at line 35
  and `sut.send(envelope:)`. Tests should keep passing (minus the dropped param).

### Reference PRs (recent ObjC→Swift conversions)

- **#8099** `ref: convert SentrySamplerDecision to Swift` — pbxproj removal pattern, `sdk_api.json` regen.
- **#7003** `ref: Convert SentryNSURLRequestBuilder to Swift` — closest sibling (networking, request builder).
- **#7162** `docs: Add guide to convert integrations to Swift` — general conversion guidance.
- `develop-docs/SWIFT.md` — Swift/ObjC bridging rules (`@_spi(Private)`, `@_implementationOnly import _SentryPrivate`).

### Template for the new file

`Sources/Swift/Networking/SentryNSURLRequestBuilder.swift` and
`SentryHttpTransportHttpStatusCodeLogger.swift`:

- `@_implementationOnly import _SentryPrivate` + `import Foundation`
- `@_spi(Private) @objc(SentrySpotlightTransport) public final class ... : NSObject`
- Log via `SentrySDKLog.warning(...)` / `.error(...)`

---

## Step-by-step plan

Each step = one small commit. Update the checkbox + "Status" line here as we go.

- [ ] **Step 0 — Setup**: branch + this plan file. _(commit: `docs: add spotlight transport conversion plan`)_
- [ ] **Step 1 — Expose ObjC protocols to Swift module**: add `SentryTransport.h` and
      `SentryRequestManager.h` to `Sources/Sentry/include/SentryPrivate.h`. Build
      (`make build-ios`) to confirm the Swift module still compiles and the protocols are visible.
      _(commit: `build: expose transport protocols to Swift module`)_
- [ ] **Step 2 — Add Swift class**: create `Sources/Swift/Networking/SentrySpotlightTransport.swift`
      conforming to `Transport`, holding `requestManager` + `requestBuilder` + `options`, with
      `apiURL` computed from `options.spotlightUrl`. Port `sendEnvelope`/`send(envelope:)`, empty
      `flush`/`recordLostEvent`/`storeEnvelope`/`setStartFlushCallback`. Drop `dispatchQueueWrapper`.
      Do **not** delete the ObjC file yet — this step must fail to compile only on duplicate-symbol,
      so temporarily rename/guard if needed, OR go straight to Step 3 in the same commit if the
      linker complains. _(commit: `ref: add Swift SentrySpotlightTransport`)_
- [ ] **Step 3 — Remove ObjC file + rewire**: `git rm` the `.m`/`.h`, edit `project.pbxproj` to drop
      references, update `SentryTransportFactory.m` (remove `#import`, drop `dispatchQueueWrapper:`
      arg — the type is now Swift so it's picked up via `SentrySwift.h`), remove
      `SentrySpotlightTransport.h` from any include umbrella. _(commit: `ref: remove ObjC SentrySpotlightTransport`)_
- [ ] **Step 4 — Fix test call site**: update `SentrySpotlightTransportTests.swift:35` to drop the
      `dispatchQueueWrapper:` argument. _(commit: `test: update spotlight transport init call`)_
- [ ] **Step 5 — Verify**: `make format`, `make analyze`, `make build-ios`,
      `make test-ios ONLY_TESTING=SentryTests/SentrySpotlightTransportTests`. Regenerate public API
      if surface changed (`make generate-public-api`). _(commit: `test: verify spotlight transport conversion` / or fold into prior)_
- [ ] **Step 6 — Changelog**: `ref:` type = no changelog; ensure `#skip-changelog` will go in PR
      description later. Update this plan to ✅.

### Fallback (if Step 1/2 build fails)

Define a minimal Swift-side transport the class conforms to (mirroring
`SentryTelemetryProcessorTransport` in `Sources/Swift/Tools/TelemetryProcessor/`), and/or keep a
thin ObjC shim. Record the exact error here before switching approaches.

---

## Verification checklist (run before considering done)

```bash
make format
make analyze
make build-ios
make test-ios ONLY_TESTING=SentryTests/SentrySpotlightTransportTests
make generate-public-api   # only if public API surface changed; commit sdk_api.json diff
```

## Progress log

- 2026-07-15: Research complete. Branch created. Plan written. Decisions confirmed.
