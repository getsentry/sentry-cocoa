# Plan: Convert `SentrySpotlightTransport` from ObjC to Swift

**Branch:** `ref/convert-spotlight-transport-to-swift`
**Status:** 🔴 BLOCKED — awaiting a decision on approach (see "⛔ Blocker" below). Branch currently
builds green (only Step 1 committed; ObjC class still in place).
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

## ⛔ Blocker (discovered during Step 2/3 — compiler-verified 2026-07-15)

Attempting the direct conversion produced **hard compile errors** that trace back to a real
architectural constraint documented in `develop-docs/SWIFT.md:13`:

> "An ObjC class that uses a non-public ObjC type in its API is not ready to be converted to
> Swift until the type it uses is also converted to Swift."

`SentrySpotlightTransport` depends on **two ObjC protocols that are still internal** and only
reachable via `@_implementationOnly import _SentryPrivate`:

- `SentryTransport` (`NS_SWIFT_NAME(Transport)`) — the protocol the class must conform to.
- `SentryRequestManager` (`NS_SWIFT_NAME(RequestManager)`) — the type of an init parameter.
- (plus enums `SentryFlushResult`, `SentryDataCategory`, `SentryDiscardReason` in the API)

Because those come from an `@_implementationOnly` import, they **cannot appear in any `public`
API**. That creates a fork with no clean exit at the current altitude:

| Attempt                                              | Result                                                                                                                                                                                                                          |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `public final class … : Transport`                   | ❌ `cannot use protocol 'Transport' in a public conformance; '_SentryPrivate' has been imported as implementation-only`. Also `RequestManager` can't be a public `init` param.                                                  |
| `internal final class … : Transport` (drop `public`) | ✅ **Compiles & conforms cleanly.** ❌ But internal `@objc` classes are **not** emitted into the ObjC-visible generated `Sentry-Swift.h`, so `SentryTransportFactory.m` errors: `unknown type name 'SentrySpotlightTransport'`. |
| `public class` + conformance in an `extension`       | ❌ Same public-conformance error; plus methods "must be declared public".                                                                                                                                                       |

This is exactly the constraint that forced `SentryTelemetryProcessorTransport` to exist
(`Sources/Swift/Tools/TelemetryProcessor/`): it defines a **Swift-side `@objc public` protocol**
as the boundary type instead of using the `@_implementationOnly` ObjC one.

### Decision needed — pick a path (see "Options" below)

**Option A — Convert the ObjC protocols first (unblocks a clean conversion).**
Convert `SentryTransport` and `SentryRequestManager` to `@_spi(Private) @objc public` Swift
protocols (like `RateLimits`, `SentryReachabilityObserver`, `SentryCurrentDateProvider` already are).
Then `SentrySpotlightTransport` (and eventually `SentryHttpTransport`) can be a clean `public`
Swift class. Largest blast radius — `SentryHttpTransport`, `SentryTransportAdapter`,
`SentryQueueableRequestManager`, and many call sites reference these protocols — but it's the
"correct" order per `SWIFT.md` and unblocks the whole transport layer. **Should likely be its own
PR(s) before this one.**

**Option B — Swift factory shim (localized, mirrors TelemetryProcessor).**
Keep `SentrySpotlightTransport` as an **internal** `@objc` Swift class (conforms to `Transport`
fine). Add a small `@objc public` Swift factory that returns the instance typed as the ObjC
`id<SentryTransport>` (the ObjC factory already stores `NSArray<id<SentryTransport>>`), so ObjC
never names the concrete class. Needs verification that a `@objc public func ->` returning the
ObjC protocol is allowed (the protocol type itself is `@_implementationOnly`, so the return type
may also be rejected — **must prototype**). If the return type is rejected, fall back to returning
`NSObject`/`AnyObject` and casting in ObjC, or to Option C.

**Option C — Defer / abandon.**
Leave `SentrySpotlightTransport` in ObjC until the transport-protocol conversion (Option A) lands.
Keep only the harmless Step 1 (protocols exposed to Swift module) if useful, or revert entirely.

### WIP reference implementation (compiles as an _internal_ class)

The Swift port below is complete and **compiles + conforms to `Transport`** when declared
`internal` (remove `@_spi(Private)` / `public`). Preserved here so the work isn't lost; it is NOT
in the build (kept out of `Sources/Swift` so it isn't auto-compiled).

```swift
// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

// NOTE: `public` here is what breaks the build. As `internal` it compiles & conforms, but then
// ObjC (SentryTransportFactory.m) can't see the type. See Options A/B above.
@objc(SentrySpotlightTransport) final class SentrySpotlightTransport: NSObject, Transport {

    private let options: Options
    private let requestManager: RequestManager
    private let requestBuilder: SentryNSURLRequestBuilder
    private let apiURL: URL?

    @objc init(
        options: Options,
        requestManager: RequestManager,
        requestBuilder: SentryNSURLRequestBuilder
    ) {
        self.options = options
        self.requestManager = requestManager
        self.requestBuilder = requestBuilder
        self.apiURL = URL(string: options.spotlightUrl)
        super.init()
    }

    func send(envelope: SentryEnvelope) {
        guard let apiURL = apiURL else {
            SentrySDKLog.warning("Malformed Spotlight URL passed from the options. Not sending envelope to Spotlight with URL:\(options.spotlightUrl)")
            return
        }

        // Spotlight can only handle the following envelope items.
        // Not removing them leads to an error and events won't get displayed.
        let allowedEnvelopeItems = envelope.items.filter { item in
            item.header.type == SentryEnvelopeItemTypes.event
                || item.header.type == SentryEnvelopeItemTypes.transaction
        }

        let envelopeToSend = SentryEnvelope(header: envelope.header, items: allowedEnvelopeItems)

        let request: URLRequest
        do {
            request = try requestBuilder.createEnvelopeRequest(envelopeToSend, url: apiURL)
        } catch {
            SentrySDKLog.error("Unable to build envelope request with error \(error)")
            return
        }

        requestManager.add(request) { _, error in
            if let error = error {
                SentrySDKLog.error("Error while performing request \(error)")
            }
        }
    }

    func store(_ envelope: SentryEnvelope) {
        send(envelope: envelope)
    }

    func flush(_ timeout: TimeInterval) -> SentryFlushResult {
        // Empty on purpose
        return .success
    }

    func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason) {
        // Empty on purpose
    }

    func recordLostEvent(_ category: SentryDataCategory, reason: SentryDiscardReason, quantity: UInt) {
        // Empty on purpose
    }

    #if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    func setStartFlushCallback(_ callback: @escaping () -> Void) {
        // Empty on purpose
    }
    #endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
}
// swiftlint:enable missing_docs
```

Notes captured while porting:

- `store(_:)` — the `Transport` protocol's `storeEnvelope:` is exposed to Swift as `store(_:)`
  (the compiler flagged `storeEnvelope` as renamed). The ObjC selector is unchanged.
- `flush` returns `.success` (Swift name for `kSentryFlushResultSuccess`).
- `item.header.type` is reachable from the Swift module even though `header` is `internal`.
- `requestManager.add(_:completionHandler:)` is the Swift name for `addRequest:completionHandler:`.

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

- [x] **Step 0 — Setup**: branch + this plan file. _(commit: `docs: add spotlight transport conversion plan`)_
- [x] **Step 1 — Expose ObjC protocols to Swift module**: added `SentryTransport.h` and
      `SentryRequestManager.h` to `Sources/Sentry/include/SentryPrivate.h`. ✅ `make build-ios`
      succeeded — no dependency explosion, protocols now visible to the Swift module.
      _(commit: `build: expose transport protocols to Swift module`)_
- [~] **Step 2 — Add Swift class**: attempted; **BLOCKED**. The class compiles & conforms to
  `Transport` only as an `internal` class, which ObjC can't see. See "⛔ Blocker". WIP preserved
  in this doc. No commit — reverted to keep branch green.
- [~] **Step 3 — Remove ObjC file + rewire**: attempted (`git rm` + pbxproj edit + factory rewire);
  reverted because Step 2 is blocked. The pbxproj `sed` deletion and factory param-drop both
  work mechanically and are documented for reuse once unblocked. No commit.
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

> **Local sim note:** the default `IOS_DEVICE_NAME`/`IOS_SIMULATOR_OS` are not installed on this
> machine. Append `IOS_DEVICE_NAME="iPhone 17 Pro" IOS_SIMULATOR_OS=26.4` to build/test targets.

```bash
make format
make analyze
make build-ios IOS_DEVICE_NAME="iPhone 17 Pro" IOS_SIMULATOR_OS=26.4
make test-ios ONLY_TESTING=SentryTests/SentrySpotlightTransportTests IOS_DEVICE_NAME="iPhone 17 Pro" IOS_SIMULATOR_OS=26.4
make generate-public-api   # only if public API surface changed; commit sdk_api.json diff
```

## Progress log

- 2026-07-15: Research complete. Branch created. Plan written. Decisions confirmed.
- 2026-07-15: Step 1 done — exposed `SentryTransport.h` + `SentryRequestManager.h` to
  `SentryPrivate.h`; `make build-ios` succeeded.
- 2026-07-15: Steps 2/3 attempted → **BLOCKED**. Compiler confirms `Transport`/`RequestManager`
  (from `@_implementationOnly _SentryPrivate`) cannot appear in a `public` API. `internal` class
  conforms but is invisible to the ObjC factory. Reverted ObjC deletion + factory rewire; branch
  is green with only Step 1. Documented the fork (Options A/B/C) and preserved the WIP Swift port.
  **Awaiting decision on approach before proceeding.**
