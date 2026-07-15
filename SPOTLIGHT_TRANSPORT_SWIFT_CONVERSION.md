# Plan: Convert `SentrySpotlightTransport` from ObjC to Swift

**Branch:** `ref/convert-spotlight-transport-to-swift`
**Status:** 🟢 Unblocked — **Option A chosen** (convert `SentryRequestManager` + `SentryTransport`
protocols to Swift first, then the class). Branch builds green (Step 1 committed; ObjC class still
in place). Next: Phase A1. See "✅ Chosen approach" below.
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

## ✅ Chosen approach: Option A — convert the protocols to Swift first

**Decision (user, 2026-07-15):** Convert the ObjC protocols to Swift `@objc` protocols first (the
"correct" order per `develop-docs/SWIFT.md`), then convert `SentrySpotlightTransport` cleanly on
top. This is a multi-PR effort; `SentrySpotlightTransport` is the final, small payoff.

### Feasibility — verified in-repo (2026-07-15)

The pattern is already proven by existing code, so Option A is low-risk mechanically:

- **Swift `@objc` protocol consumed by ObjC:** `RateLimits.swift` is
  `@objc(SentryRateLimits) @_spi(Private) public protocol RateLimits: NSObjectProtocol`. ObjC refers
  to it via a forward decl `@protocol SentryRateLimits;` and `id<SentryRateLimits>`.
- **ObjC class _conforming_ to a Swift `@objc` protocol:** `SentryHttpTransport.m` already adopts the
  Swift-defined `SentryReachabilityObserver` (`@interface SentryHttpTransport () <SentryReachabilityObserver>`),
  importing it via `SentrySwift.h`. So `SentryHttpTransport`, `SentryQueueableRequestManager`, and
  `SentryTransportAdapter` can keep conforming after the protocols move to Swift.

### ⚠️ Do NOT convert the data-category enums

`SentryDataCategory` (**138** `k*` refs) and `SentryDiscardReason` (**69** refs) are used pervasively
across ObjC (214 constant references, 10+ files). Converting them is out of scope and high-risk.
Follow the `RateLimits` precedent instead: **the Swift protocol uses `UInt`** for the category/reason
params; ObjC conformers keep their existing `NS_ENUM(NSUInteger)`-typed method signatures, which are
selector- and ABI-compatible. Only `SentryFlushResult` (**7** refs, defined solely in
`SentryTransport.h`) is small enough to convert to a Swift `@objc enum ... : Int` if needed — or it
can also be bridged as `UInt`/`Int`.

### 🔬 Must prototype first (the one unproven mechanic)

Whether an ObjC method typed `- (void)recordLostEvent:(SentryDataCategory)category …` satisfies a
Swift `@objc` protocol requirement declared `func recordLostEvent(_ category: UInt, …)`.
`NS_ENUM(NSUInteger)` bridges to `UInt`, so it _should_ match by selector — but no existing repo case
proves ObjC _conforming_ with an enum param to a `UInt` requirement. Prove this in a throwaway build
at the start of Step A2 before committing to the protocol shape. If it fails, the protocol requirement
can instead be typed with the enum (still `@_implementationOnly` inside Swift — acceptable for a
non-public `@objc` protocol method as long as it isn't in a _public Swift_ signature; verify).

### Ordering / PR strategy

Each of A1–A3 is independently shippable and should likely be its **own PR** (merged in order),
with the small A4 (the actual spotlight conversion) last. All work stays on this branch for now via
small commits; we split into PRs when ready.

- [x] **Step 0 — Setup**: branch + plan. _(committed)_
- [x] **Step 1 — Expose ObjC protocols to Swift module**: added `SentryTransport.h` +
      `SentryRequestManager.h` to `SentryPrivate.h`; build green. _(committed)_
      → **Superseded by Option A** (the protocols will _move_ to Swift, not just be exposed). This
      commit is harmless to keep meanwhile; revisit/replace in Step A1.

**Phase A1 — Convert `SentryRequestManager` → Swift** (simplest; 1 method + 1 block + 1 init)

- [ ] **A1.1** Prototype: create `Sources/Swift/Networking/SentryRequestManager.swift` as
      `@objc(SentryRequestManager) @_spi(Private) public protocol RequestManager: NSObjectProtocol`
      with `add(_:completionHandler:)` (`NS_SWIFT_NAME` already maps this). Model the completion
      block type — `SentryRequestOperationFinished` is `(NSHTTPURLResponse?, NSError?) -> Void`.
- [ ] **A1.2** Remove ObjC `include/SentryRequestManager.h`; update `SentryPrivate.h` (drop the
      import added in Step 1); add forward decls / `SentrySwift.h` imports in ObjC consumers
      (`SentryQueueableRequestManager.{h,m}`, `SentryHttpTransport.{h,m}`, `SentryTransportFactory.m`,
      `SentryRequestOperation.h`). Edit `project.pbxproj` to drop the `.h`.
- [ ] **A1.3** Build all affected platforms + run transport tests. _(commit/PR: `ref: convert SentryRequestManager to Swift`)_

**Phase A2 — Convert `SentryTransport` (+ `SentryFlushResult`) → Swift**

- [ ] **A2.1** Prototype the enum-param conformance question (see 🔬 above) in a throwaway build.
- [ ] **A2.2** Create `Sources/Swift/Networking/SentryTransport.swift`:
      `@objc(SentryTransport) @_spi(Private) public protocol Transport: NSObjectProtocol` with
      `send(envelope:)`, `store(_:)`, `recordLostEvent(_:reason:)` + `(…quantity:)` (params `UInt`),
      `flush(_:)`, and the `#if DEBUG…` `setStartFlushCallback`. Convert `SentryFlushResult` to a
      Swift `@objc enum` (or bridge as Int) in the same file/PR.
- [ ] **A2.3** Remove ObjC `include/SentryTransport.h`; update `SentryPrivate.h`; fix ObjC
      conformers (`SentryHttpTransport`, `SentryTransportAdapter`, `SentrySpotlightTransport` — still
      ObjC at this point) and `SentryTransportFactory.m` / `SentryClient.m`. pbxproj drop.
- [ ] **A2.4** Build all platforms + tests. _(commit/PR: `ref: convert SentryTransport protocol to Swift`)_

**Phase A3 — Convert `SentrySpotlightTransport` → Swift** (the original goal; now unblocked)

- [ ] **A3.1** Add `Sources/Swift/Networking/SentrySpotlightTransport.swift` as
      `@_spi(Private) @objc(SentrySpotlightTransport) public final class … : NSObject, Transport`
      (the WIP above, upgraded from `internal` to `public` now that `Transport`/`RequestManager` are
      Swift). Drop `dispatchQueueWrapper`.
- [ ] **A3.2** Remove ObjC `SentrySpotlightTransport.{h,m}`; pbxproj drop (`sed '/SpotlightTransport/d'`
      — 8 lines, verified with `plutil -lint`); rewire `SentryTransportFactory.m` (drop `#import`
      + `dispatchQueueWrapper:` arg).
- [ ] **A3.3** Update `SentrySpotlightTransportTests.swift:35` — drop `dispatchQueueWrapper:` arg.
- [ ] **A3.4** `make format && make analyze && make build-ios` (+ other platforms) + spotlight tests;
      `make generate-public-api` if surface changed. _(commit/PR: `ref: convert SentrySpotlightTransport to Swift`)_

### If A2.1 prototype fails (enum param can't satisfy `UInt` requirement)

Fall back to typing the protocol's `recordLostEvent` params with the ObjC enums directly (the enums
stay ObjC, imported into Swift via `_SentryPrivate`; acceptable inside a non-public-Swift `@objc`
protocol method). Record the exact error before switching.

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
- 2026-07-15: **Option A chosen.** Researched full blast radius: protocol pattern proven in-repo
  (`RateLimits.swift` + `SentryHttpTransport.m` conforming to Swift `SentryReachabilityObserver`).
  Enums stay ObjC (214 refs) — protocols use `UInt` per `RateLimits` precedent. Rewrote plan into
  Phases A1 (`SentryRequestManager`) → A2 (`SentryTransport`+`SentryFlushResult`) → A3 (the class).
  Next action: Phase A1.1 (prototype Swift `RequestManager` protocol).
