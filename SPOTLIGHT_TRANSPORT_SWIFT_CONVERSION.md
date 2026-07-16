# Plan: Convert `SentrySpotlightTransport` from ObjC to Swift

## 🚀 RESUME HERE (read this first — for a fresh agent picking this up)

**Goal:** convert `Sources/Sentry/SentrySpotlightTransport.{h,m}` to Swift. It is **blocked** on two
ObjC protocols it depends on (`SentryRequestManager`, `SentryTransport`) — they must become Swift
first (`@_implementationOnly` ObjC types can't appear in a public Swift API). We chose **Option A**:
convert those protocols first, in small sequential PRs to `main`, then convert the class last.

**✅ A1 MERGED (2026-07-16).** PR #8428 (`SentryRequestManager` → Swift) merged to `main` as
`8e6a36fbd`. This tracker branch has since **merged `origin/main` back in** (merge commit on
`ref/convert-spotlight-transport-to-swift`) so it now carries the authoritative A1 **plus** the A2
WIP. Conflicts resolved: `SentryRequestManager.swift` took main's version (the shipped A1); the two
transport headers (`SentryHttpTransport.h`, `SentrySpotlightTransport.h`) kept the A2 versions
(`#import "SentrySwift.h"`, since A2 moves `SentryTransport` to Swift). `make build-ios` green after
the merge. The tracker's old standalone A1 commit is no longer relevant — main's A1 is what ships.

**Where everything lives (all pushed to `origin`, nothing local-only):**

- `ref/convert-spotlight-transport-to-swift` ← **THIS branch = the tracker.** Holds this plan doc +
  the A2 work-in-progress, now synced with `main` (A1 merged in). Not a PR.
- `main` ← base for every PR. **Contains A1** (`8e6a36fbd`).

**Do this next — A1 is merged, so create the A2 PR:**

- `git checkout main && git pull`
- `git checkout -b ref/convert-transport-protocol-to-swift`
- Apply the A2 code from this tracker branch (`SentryTransport.swift` + all A2 edits), but **NOT**
  the plan doc. (The A2 files are listed in "Phase A2" below.)
- **Finish the unfinished A2 test work** (this is the only incomplete part — see **A2.4** below):
  ~12 `sut.recordLostEvent(.enumCase, …)` sites in `SentryHttpTransportTests.swift` need
  `.rawValue`, and `SentryHttpTransportFlushIntegrationTests.swift` needs `sut` retyped to
  `Transport` (same treatment already applied to `SentryHttpTransportTests`).
- Build + test (commands below), push, `gh pr create --draft`, then mark ready.
- Then update this tracker branch's PR table once A2's PR number exists.

**Environment quirk (IMPORTANT):** `make build-ios` / `make test-ios` default to a simulator that is
**not installed** here. Always append: `IOS_DEVICE_NAME="iPhone 17 Pro" IOS_SIMULATOR_OS=26.4`.
`ONLY_TESTING` takes **comma-separated** targets (not space). Pre-commit hooks reformat md/swift —
re-`git add` and re-commit if a hook edits files.

---

**Branch:** `ref/convert-spotlight-transport-to-swift`
**Status:** 🟢 In progress — **Option A**, shipped as small PRs to `main`.
Phase A1 (`SentryRequestManager` → Swift) ✅ **merged** → PR #8428 (`8e6a36fbd` on `main`).
Phase A2 (`SentryTransport`) WIP on this branch (source builds green, tests not yet building) — next
up as its own PR now that A1 has merged.
See "PR tracking" and "✅ Chosen approach" below.

## PR tracking

Small, **unstacked** PRs to `main`, opened as **drafts** first. Sequenced (not stacked) because the
phases share files (headers + pbxproj). This branch (`ref/convert-spotlight-transport-to-swift`) is
the **plan/WIP tracker only** — its commits are NOT the PRs. Each PR is a clean branch cut from
`main` containing only that phase's code (no plan doc).

| Phase                                              | PR branch                              | PR                                                           | Status                                                               |
| -------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------- |
| A1 `SentryRequestManager` → Swift                  | `ref/convert-request-manager-to-swift` | [#8428](https://github.com/getsentry/sentry-cocoa/pull/8428) | ✅ **merged** (`8e6a36fbd`)                                          |
| A2 `SentryTransport` + `SentryFlushResult` → Swift | _tbd_                                  | —                                                            | 🔧 next up — WIP on tracker branch; finish test churn (see A2 notes) |
| A3 `SentrySpotlightTransport` → Swift              | _tbd_                                  | —                                                            | ⛔ depends on A2                                                     |

**Workflow per phase:** cut `<branch>` from latest `main` → cherry-pick/apply that phase's code
(drop the plan doc) → `make build-ios` + targeted tests → push → `gh pr create --draft`. After a PR
merges, rebase the next phase's branch on the new `main` and continue.

**A2/A3 cannot be truly parallel** with A1: they edit the same headers (`SentryHttpTransport.h`,
`SentrySpotlightTransport.h`, `SentryPrivate.h`) and `project.pbxproj`. Per user: do A1 first, wait
for merge, then reassess.
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

- [x] **A1.1** Created `Sources/Swift/Networking/SentryRequestManager.swift`:
      `@objc(SentryRequestManager) @_spi(Private) public protocol RequestManager: NSObjectProtocol`
      with `isReady` + `@objc(addRequest:completionHandler:) func add(_:completionHandler:)`.
      **Dropped the `initWithSession:` requirement** — it was never called through the protocol
      (only on the concrete class), so it moved to `SentryQueueableRequestManager.h` directly.
      Completion type is the existing `SentryRequestOperationFinished` block (public, visible to Swift).
- [x] **A1.2** Removed ObjC `include/SentryRequestManager.h`; dropped its import from
      `SentryPrivate.h`; `SentryQueueableRequestManager.h` now imports `SentrySwift.h` (conforms to
      the Swift protocol, like `SentryDefaultTelemetryProcessorTransport.h`); `SentryHttpTransport.h`
      + `SentrySpotlightTransport.h` use forward decl `@protocol SentryRequestManager;` (like
      `SentryRateLimits`); `.m` consumers already import `SentrySwift.h`. Dropped 6 pbxproj lines
      (`plutil -lint` OK).
- [x] **A1.3** ✅ `make build-ios` green; **81 transport tests pass** (Spotlight + Factory + Http).
      Fixed test fallout: `TestRequestManager`/`SyncTestRequestManager` dropped `public` (can't be
      public conformers of an SPI protocol); `SentryTransportFactoryTests` casts to `RequestManager`
      instead of the concrete class to reach `.add`. `RequestManager` is SPI → not in `sdk_api.json`,
      no public-API regen needed. _(commit: `ref: convert SentryRequestManager to Swift`)_

**Phase A2 — Convert `SentryTransport` (+ `SentryFlushResult`) → Swift**
_(WIP checkpointed on tracker branch commit `565aac5f3`; **source builds green, tests do not yet
build**. To be turned into its own PR after A1 merges.)_

- [x] **A2.1** Enum-param conformance question **answered — it FAILS.** With the protocol requirement
      typed `UInt`, ObjC conformers whose method signatures use the `SentryDataCategory` /
      `SentryDiscardReason` enums produce `-Wmismatched-parameter-types` (which is `-Werror` here):
      `conflicting parameter types … 'NSUInteger' vs 'SentryDataCategory'`. And typing the protocol
      requirement with the enums directly fails too (`cannot use enum 'SentryDataCategory' here;
      '_SentryPrivate' has been imported as implementation-only`). **Resolution:** protocol uses
      `UInt`; the two ObjC conformers (`SentryHttpTransport`, `SentrySpotlightTransport`) change their
      `recordLostEvent` signatures to `NSUInteger` and cast to the enum internally.
- [x] **A2.2** Created `Sources/Swift/Networking/SentryTransport.swift`:
      `@objc(SentryTransport) @_spi(Private) public protocol Transport: NSObjectProtocol`
      (`send(envelope:)`, `store(_:)`, two `recordLostEvent` overloads with `UInt` params,
      `flush(_:) -> SentryFlushResult`, `#if DEBUG…` `setStartFlushCallback`) + a Swift
      `@objc(SentryFlushResult) @_spi(Private) public enum SentryFlushResult: Int`
      (`success`/`timedOut`/`alreadyFlushing`). ObjC `k*` constants → `SentryFlushResult*`.
- [x] **A2.3** Removed ObjC `include/SentryTransport.h`; dropped from `SentryPrivate.h`; conformer
      headers (`SentryHttpTransport.h`, `SentrySpotlightTransport.h`) import `SentrySwift.h`;
      reference-only headers (`SentryTransportFactory.h`, `SentryTransportAdapter.h`) use forward
      decl `@protocol SentryTransport;`; `.m` files drop the import; `SentryHttpTransport.m` +
      `SentrySpotlightTransport.m` `recordLostEvent` params → `NSUInteger` with internal casts;
      `SentryTransportAdapter.m` `flush` call → `(void)[transport flush:…]` (Swift enum return is
      `warn_unused_result`). pbxproj drop (6 lines, `plutil -lint` OK). **`make build-ios` green.**
- [~] **A2.4** ⚠️ **Tests need broad updates — IN PROGRESS.** Because the old ObjC protocol used
  `NS_SWIFT_NAME(send(envelope:))` etc., concrete conformers exposed those Swift names directly.
  A Swift `@objc` protocol does **not** propagate names to concrete ObjC types, so Swift tests
  calling `sut.send(envelope:)`/`.flush(_:)`/`.recordLostEvent(_:…)` on a concrete
  `SentryHttpTransport`/`SentrySpotlightTransport` must instead go through the `Transport`
  protocol type. Work done so far: `TestTransport` (`SentryTestUtils`) made `@_spi(Private)
      public`, `import Sentry` added, `recordLostEvent` params → `UInt` (records via
  `SentryDataCategory(rawValue:)`); `SentrySpotlightTransportTests.givenSut` returns `Transport`;
  `SentryHttpTransportTests` `sut`/`getSut` retyped to `Transport`; test bridging headers +
  `SentryClient+TestInit.h` drop `SentryTransport.h`. **Still TODO:** ~12 `recordLostEvent(.enum…)`
  call sites in `SentryHttpTransportTests` need `.rawValue`; `SentryHttpTransportFlushIntegrationTests`
  needs the same `Transport`-typing treatment; re-run full transport tests.
  _(commit/PR: `ref: convert SentryTransport protocol to Swift`)_

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
- 2026-07-15: **Phase A1 done.** `SentryRequestManager` is now a Swift `@objc` protocol. Build
  green; 81 transport tests pass. Proved the core Option A mechanic: an ObjC class
  (`SentryQueueableRequestManager`) conforms to a Swift `@objc @_spi(Private)` protocol, and ObjC
  callers reference it via forward decl / `id<SentryRequestManager>`.
- 2026-07-15: **Phase A2 (SentryTransport) — source converted, build green, tests WIP.** Discovered
  A2.1 fails: under `-Werror`, ObjC enum-typed `recordLostEvent` can't satisfy a Swift `UInt`
  requirement, and the enums can't be used in the SPI-public protocol — so conformers switch to
  `NSUInteger` + internal casts. Also found the Swift `@objc` protocol drops the old
  `NS_SWIFT_NAME`s, forcing many test call sites onto the `Transport` protocol type (in progress).
- 2026-07-15: **Strategy change (user).** Ship Option A as small **unstacked draft PRs to `main`**,
  sequentially. Cut a clean code-only branch per phase from `main` (plan doc stays on tracker
  branch). A2 WIP checkpointed here (commit `565aac5f3`). Opened **A1 as draft PR #8428**; waiting
  for it to merge before continuing A2. Recorded workflow + PR table under "PR tracking".
- 2026-07-15: **A1 review revisions** (on `ref/convert-request-manager-to-swift`, amended +
  force-pushed; now PR #8428 HEAD `c0fedb958`): removed the doc comments from
  `SentryRequestManager.swift` (used `// swiftlint:disable missing_docs` like sibling files, since
  the `missing_docs` lint blocks undocumented public decls). Kept the `SentryTransportFactoryTests`
  cast as `as? RequestManager` (not the concrete `SentryQueueableRequestManager`) — verified the
  concrete cast can't work because `SentryQueueableRequestManager.h` never declares
  `addRequest:completionHandler:` (it lives only in the `.m`), so Swift only sees `add(...)` through
  the protocol type. PR marked **ready for review**. NOTE: this tracker branch's own A1 commit
  (`0d436f62e`) predates these revisions — the authoritative A1 is the PR branch, not this copy.
- 2026-07-16: **A1 MERGED.** PR #8428 auto-merged to `main` as `8e6a36fbd` (nit addressed in review:
  split `@_spi(Private)` / `@objc(SentryRequestManager)` onto two lines; CI flakes on
  `postman-echo.com` network test + parallel session-count tests were re-run to green). Then
  **merged `origin/main` into this tracker branch.** 3 conflicts resolved: `SentryRequestManager.swift`
  → took main's shipped A1; `SentryHttpTransport.h` + `SentrySpotlightTransport.h` → kept the A2
  versions (`#import "SentrySwift.h"`). `make build-ios` green post-merge. **A2 is now unblocked and
  next up as its own PR.**
