# Plan: Convert `SentrySpotlightTransport` from ObjC to Swift

## 🚀 RESUME HERE (read this first — for a fresh agent picking this up)

**Goal:** convert `Sources/Sentry/SentrySpotlightTransport.{h,m}` to Swift. It is **blocked** on two
ObjC protocols it depends on (`SentryRequestManager`, `SentryTransport`) — they must become Swift
first (`@_implementationOnly` ObjC types can't appear in a public Swift API). We chose **Option A**:
convert those protocols first, in small sequential PRs to `main`, then convert the class last.

**Progress so far (all merged to `main`):**

- ✅ **A1 `SentryRequestManager` → Swift** — PR #8428, **merged** to `main`.
- ✅ **A2a1 `SentryDiscardReason` → Swift** — PR #8444, **merged** to `main` as `bacd00766` (2026-07-16).
- ✅ **A2a2 `SentryDataCategory` → Swift** — PR **#8451**, **merged** to `main` as `487d99372`
  (2026-07-20). All three enum/protocol prerequisites are now in `main`.
- ✅ **A2 `SentryTransport` → Swift** — PR **#8443**, **merged** to `main` (2026-07-21T09:50Z), with
  the real enum types (`SentryDataCategory`/`SentryDiscardReason`), not `UInt`. All four
  prerequisites (A1, A2a1, A2a2, A2) are now in `main`.
- ⛔ **A3 `SentrySpotlightTransport` class → Swift** — last step, now fully unblocked. **NEXT AND
  ONLY REMAINING WORK.**

**2026-07-23: tracker branch merged with `main`.** Merged `origin/main` into
`ref/convert-spotlight-transport-to-swift` (merge commit `05d67ba50`). One conflict, exactly as
predicted below: `Sources/Swift/Networking/SentryTransport.swift` was add/add (this branch's stale
pre-enum WIP vs. the real merged A2 file) — resolved by taking `origin/main`'s version verbatim
(discarding the stale WIP, as intended). Build then failed on merge fallout: `SentrySpotlightTransport.m`
still declared `recordLostEvent` with `NSUInteger` params, but the merged `Transport` protocol now
requires the real enum types — same fix `SentryHttpTransport.m` already got in A2. Applied the
one-line-per-method fix (`NSUInteger` → `SentryDataCategory`/`SentryDiscardReason`) so the merge
itself builds; this is **not** A3 (the class is still ObjC). Verified: `make build-ios` ✅, 84
tests (Spotlight + Http + Factory) ✅. **Not yet committed separately — pending user confirmation**
(this fix will likely be folded into the merge commit or a small follow-up commit; see chat).
Nothing pushed. **A3 itself (the actual class-to-Swift conversion) has not been started** — confirmed
`Sources/Sentry/SentrySpotlightTransport.{h,m}` is still ObjC and `SentrySpotlightTransportTests.swift`
still passes `dispatchQueueWrapper:`. Next: follow the "RESUME HERE — A3" steps below.

**🔁 WHY THE ENUM DETOUR (context).** The user requires the ObjC transport conformers to use the **real
enum types** (`SentryDataCategory` / `SentryDiscardReason`), not `NSUInteger`. Verified empirically that
is impossible while the `Transport` protocol requirement is typed `UInt`: an ObjC conformer with an
enum-typed `recordLostEvent` fails `-Wmismatched-parameter-types -Werror`. So both enums had to become
Swift first (now done) — then the protocol + conformers can use the real types.

**Where everything lives:**

- `ref/convert-spotlight-transport-to-swift` ← **THIS branch = the tracker.** As of 2026-07-23 it is
  **merged with `main`** (merge `05d67ba50`) — the stale pre-enum A2 WIP was discarded during that
  merge (see the resolution note above). The plan doc plus the small merge-fallout fix to
  `SentrySpotlightTransport.m` are the only local, unpushed changes. A3 itself has not started.
- `main` ← base for every PR. **Contains A1 + A2a1 + A2a2 + A2** (`SentryRequestManager`,
  `SentryDiscardReason`, `SentryDataCategory`, `SentryTransport`/`SentryFlushResult` — all with real
  enum types). All prerequisites are in. A3 is the only remaining phase.
- `ref/convert-transport-protocol-to-swift` ← **A2, PR #8443 — MERGED.** Branch can be deleted.
- `ref/convert-data-category-to-swift` ← **A2a2, PR #8451 — MERGED** (`487d99372`). Branch can be deleted.

**✅ A2 DONE (2026-07-21) — how it was re-landed:** Instead of rebasing the stale `UInt` commit, the PR
branch was **reset to `origin/main` and the real change re-applied fresh** (much smaller — the enums were
already Swift in `main`, so the ObjC conformers' enum-typed `recordLostEvent` needed no change). The user
asked for **no force-push**, so the clean commit was landed on PR #8443 via a **merge of `origin/main`
into the stale branch** whose merged tree was forced to exactly the verified clean tree (merge commit
`8f42b43ba`, normal fast-forward push). What the real change contained:

- `Sources/Swift/Networking/SentryTransport.swift`: new `@objc @_spi(Private)` `Transport` protocol +
  `SentryFlushResult: Int` enum; `recordLostEvent` typed to `SentryDataCategory` / `SentryDiscardReason`.
- Deleted `include/SentryTransport.h`; `kSentryFlushResult*` → `SentryFlushResult*` in the two conformer
  `.m` files. Conformer headers import `SentrySwift.h`; reference-only headers forward-declare
  `@protocol SentryTransport;`. Dropped 6 pbxproj refs.
- **`TestTransport.swift`** (the one plan surprise): had to become `@_spi(Private) public` (a plain
  `public` class can't conform to the now-SPI `Transport` or return the now-SPI `SentryFlushResult`);
  kept its enum-typed `recordLostEvent` (no `.rawValue`). All consumers already `@_spi(Private) import
  SentryTestUtils`.
- Test `sut` retyped to `Transport` (Http/Spotlight/FlushIntegration) — enum call sites kept as-is.
- `make generate-public-api` → additive `SentryFlushResult` only in `sdk_api.json` + `sdk_api_v10.json`.

Backup of the clean pre-merge commit: local branch `backup/a2-real-enums` (`75c658c38`).

**➡️ RESUME HERE — A3 (`SentrySpotlightTransport.{h,m}` → Swift class) — the only remaining phase:**

1. Cut a clean code-only branch from `main` (which now contains A1/A2a1/A2a2/A2 — verified
   2026-07-23). Add `Sources/Swift/Networking/SentrySpotlightTransport.swift` as
   `@_spi(Private) @objc(SentrySpotlightTransport) public final class … : NSObject, Transport` — the
   WIP in "Phase A3" below, upgraded from `internal` to `public` (Transport/RequestManager are Swift now).
   **Drop `dispatchQueueWrapper`** (stored but unused).
2. Remove ObjC `SentrySpotlightTransport.{h,m}`; pbxproj drop; rewire `SentryTransportFactory.m` (drop the
   `#import` + the `dispatchQueueWrapper:` arg).
3. `SentrySpotlightTransportTests.swift`: drop the `dispatchQueueWrapper:` arg (givenSut already returns
   `Transport`).
4. Verify: `make format` + `make analyze` + `make build-ios` + `make build-macos` + spotlight tests;
   `make generate-public-api` (the `@objc` class is NOT in the digest, but regen to be safe).

**Environment quirks (IMPORTANT):**

- `make build-ios` / `make test-ios` default to a simulator that is **not installed** here. Always append:
  `IOS_DEVICE_NAME="iPhone 17 Pro" IOS_SIMULATOR_OS=26.4`. `ONLY_TESTING` takes **comma-separated** targets.
- `make generate-public-api` requires **Xcode 16** (Xcode 26 omits the ObjC public API) **with the iOS
  platform installed**. Xcode 16.4.0 is at `/Applications/Xcode-16.4.0.app`; the iOS platform is now
  installed. If a fresh machine hits "Failed to load module: Sentry", the iOS device platform is missing
  (`xcodebuild -sdk iphoneos` falls back to macOS) — install via Xcode 16 → Platforms, or `xcodebuild
  -downloadPlatform iOS`. Set it active with `sudo xcode-select -s /Applications/Xcode-16.4.0.app/...`.
- Pre-commit hooks reformat md/swift — re-`git add` and re-commit if a hook edits files. On draft PRs the
  full CI matrix is **gated** behind the `ready-to-merge` label, so most build/test checks show as
  `skipping` and their aggregators report `fail` — that is NOT a real failure. Only the **Fast** checks
  (Fast PR Checks, Fast Unit Tests, Lint, Analyze, API Stability) actually run pre-label; judge drafts by those.

**Key learnings (don't relearn the hard way):**

- **`@objc` enums ARE in `sdk_api.json`** (SPI or not) — `swift-api-digester` dumps the ObjC-visible
  surface. Any `@objc` enum conversion needs `make generate-public-api` + committed `sdk_api.json`. (Pure
  Swift `@_spi(Private)` types and `@objc` _classes_ are NOT in the digest; `@objc` enums are.)
- **Swift `enum` is closed; ObjC `NS_ENUM` is open.** `SentryDataCategory(rawValue: 100)` returned a value
  under the old ObjC enum but returns `nil` under the Swift enum. This broke `ConcurrentRateLimitsDictionaryTests`
  (fabricated categories from raw 100/200/300) — fixed by shrinking that test's offsets to 4/8/12 (in-range)
  while keeping its original structure. Production is safe (all callers use the `init(_:)` → `.unknown` path).
- **`SentryDataCategoryMapper` had to become Swift too** (unlike `SentryDiscardReasonMapper`, which stayed
  ObjC): Swift production code (`DefaultRateLimits`, `RateLimitParser`, `SentryFileManager`) calls the
  enum-_returning_ mapper functions, and a forward-declared (incomplete) enum can't satisfy that. Mapping
  lives on the enum: intrinsic bits (`name`, `init(name:)`, `init(_ rawValue:)`) in
  `SentryDataCategory.swift`; the cross-domain `init(itemType:)` in `SentryDataCategory+EnvelopeItemType.swift`;
  an `@objc SentryDataCategoryMapper` class bridges all of it to ObjC callers.
- **Stale digests cause phantom API-stability failures.** #8444 failed because `main` merged the
  DataCollection→SDK_V10 gating (`c2a01c0f3`) without regenerating the committed digests. Fix: merge `main`
  - `make generate-public-api`. If an api-stability failure names symbols unrelated to your change, suspect
    a stale baseline, not your code.

**💡 Name-preservation option (verified, NOT chosen):** a Swift `@objc` enum can pin each case's ObjC name
with `@objc(kSentryDataCategoryError) case error = 2` — the generated `SWIFT_ENUM` emits the exact old
`k`-prefixed constant, so ObjC needs **zero** ref renames. User chose **modern non-prefixed names** (hence
the renames in A2a1/A2a2). Keep in back pocket if rename churn ever becomes a problem.

---

**Branch:** `ref/convert-spotlight-transport-to-swift`
**Status:** 🟢 In progress — **Option A**, shipped as small PRs to `main`.
Phase A1 (`SentryRequestManager`) ✅ **merged** (#8428).
Phase A2a1 (`SentryDiscardReason`) ✅ **merged** (#8444, `bacd00766`).
Phase A2a2 (`SentryDataCategory`) ✅ **merged** (#8451, `487d99372`, 2026-07-20).
Phase A2 (`SentryTransport`) ✅ **merged** (#8443, real enum types, 2026-07-21T09:50Z).
Phase A3 (`SentrySpotlightTransport`) ⛔ last — **the only remaining work.**
See "PR tracking" and "✅ Chosen approach" below.

### 🔁 Plan revision (2026-07-16, user request)

The user asked that the ObjC transport conformers use the **real enum types**, not `NSUInteger`. That
is impossible while the `Transport` protocol requirement is typed `UInt` (an ObjC conformer with an
enum-typed `recordLostEvent` fails `-Wmismatched-parameter-types -Werror` — verified empirically).
The clean fix (user-confirmed) is to **convert `SentryDiscardReason` + `SentryDataCategory` to Swift
`@objc @_spi(Private)` enums first**, each as its own PR (before finishing A2), then type the protocol

- conformers with the real enums and drop the `.rawValue` churn from A2's tests.

Key mechanic (verified): a Swift `@objc enum` bridges its cases to ObjC. With **modern naming**
(user choice), `case beforeSend` → ObjC `SentryDiscardReasonBeforeSend` (drops the old `k` prefix), so
each ObjC case ref is renamed. Headers inside the `_SentryPrivate` umbrella (which Swift imports)
**forward-declare** the enum (`typedef NS_ENUM(NSUInteger, SentryX);`) instead of importing the
generated Swift header, to avoid a module cycle; `.m` files and non-umbrella headers import
`SentrySwift.h`. The mappers stay ObjC. SPI-only → no `sdk_api.json` change.

## PR tracking

Small, **unstacked** PRs to `main`, opened as **drafts** first. Sequenced (not stacked) because the
phases share files (headers + pbxproj). This branch (`ref/convert-spotlight-transport-to-swift`) is
the **plan/WIP tracker only** — its commits are NOT the PRs. Each PR is a clean branch cut from
`main` containing only that phase's code (no plan doc).

| Phase                                              | PR branch                                 | PR                                                           | Status                                             |
| -------------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------ | -------------------------------------------------- |
| A1 `SentryRequestManager` → Swift                  | `ref/convert-request-manager-to-swift`    | [#8428](https://github.com/getsentry/sentry-cocoa/pull/8428) | ✅ **merged**                                      |
| A2a1 `SentryDiscardReason` → Swift                 | `ref/convert-discard-reason-to-swift`     | [#8444](https://github.com/getsentry/sentry-cocoa/pull/8444) | ✅ **merged** (`bacd00766`)                        |
| A2a2 `SentryDataCategory` → Swift                  | `ref/convert-data-category-to-swift`      | [#8451](https://github.com/getsentry/sentry-cocoa/pull/8451) | ✅ **merged** (`487d99372`, 2026-07-20)            |
| A2 `SentryTransport` + `SentryFlushResult` → Swift | `ref/convert-transport-protocol-to-swift` | [#8443](https://github.com/getsentry/sentry-cocoa/pull/8443) | ✅ **merged** (real enum types, 2026-07-21T09:50Z) |
| A3 `SentrySpotlightTransport` → Swift              | _tbd_                                     | —                                                            | ⛔ last — **the only remaining work**              |

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
- 2026-07-16: **A2 draft PR opened → #8443** (`ref/convert-transport-protocol-to-swift`, cut from the
  A1-merged `main`). Finished the A2.4 test work: 11 `recordLostEvent` sites in
  `SentryHttpTransportTests` + the `givenRecordedLostEvents` helper now pass `.rawValue` (protocol
  param is `UInt`); `SentryHttpTransportFlushIntegrationTests.getSut` return type retyped to
  `Transport`; added `// swiftlint:disable missing_docs` to `SentryTransport.swift` (same as the A1
  sibling — `missing_docs` blocks the undocumented protocol methods). Verified: `make build-ios` ✅,
  `make analyze` ✅, **82 transport tests, 0 failures** ✅, no `sdk_api.json` change (SPI-only). PR is
  `#skip-changelog` (type `ref`).
- 2026-07-16: **Plan revision (user).** User asked the ObjC conformers to use the real enum types, not
  `NSUInteger`. Verified empirically that's impossible while the protocol requirement is `UInt`
  (`-Wmismatched-parameter-types -Werror`). Decision: convert `SentryDiscardReason` + `SentryDataCategory`
  to Swift enums first (two separate PRs, modern non-`k` names), then rebase A2 to use the real types.
- 2026-07-16: **A2a1 draft PR opened → #8444** (`ref/convert-discard-reason-to-swift`).
  `SentryDiscardReason` is now a Swift `@objc @_spi(Private) enum: UInt`. ~33 ObjC case refs renamed
  (`kSentryDiscardReasonBeforeSend` → `SentryDiscardReasonBeforeSend`) across 4 `.m` + the mapper.
  Umbrella headers (`SentryClient+Private.h`, `SentryTransportAdapter.h`, `SentryDiscardReasonMapper.h`)
  forward-declare the enum; `SentryTransport.h` + mapper `.m` import `SentrySwift.h`; two `TestUtils`
  files gained `@_spi(Private)` on their `recordLostEvent` members; `SentryDiscardReasonMapperTests`
  gained `@_spi(Private) import Sentry`. Verified: iOS+macOS build ✅, analyze ✅, affected tests ✅
  (70, 0 failures), no `sdk_api.json` change. **Next: A2a2** — same treatment for `SentryDataCategory`
  (larger: ~138 refs, 14 files), then rebase A2 (#8443) to the real enum types and drop the `.rawValue`
  churn. A3 (`SentrySpotlightTransport`) last.
- 2026-07-16: **Public API digest — `@objc` enums ARE tracked.** Corrected an earlier wrong assumption:
  `swift-api-digester` includes `@objc` enums (SPI or not) in `sdk_api.json` (e.g. the pre-existing
  `@objc @_spi(Private) enum SentryReplayType`). So both new enums require `make generate-public-api`.
  That requires **Xcode 16** (Xcode 26 omits the ObjC public API) **with the iOS platform installed** —
  device-platform stub causes `xcodebuild -sdk iphoneos` to fall back to macOS and the digester to fail
  with "Failed to load module". Ran it for #8444 (526 additive lines) and #8451.
- 2026-07-16: **#8444 CI failure was stale-baseline, not our change.** The `Check API Stability` job
  flagged `SentryObjC` + ObjC/ObjCCompat drift removing `SentryObjCDataCollection*` symbols — unrelated
  to the enum. Root cause: `main` merged `c2a01c0f3` (gate DataCollection APIs behind SDK_V10) **without
  regenerating the committed digests**, and our branch predated it. Fix: merge `origin/main` +
  `make generate-public-api` (removed the now-gated symbols, 2900 deletions), verified a fresh regen
  yields zero diff. **#8444 now fully green (259 pass) + approved, ready to merge.**
- 2026-07-16: **A2a2 draft PR opened → #8451** (`ref/convert-data-category-to-swift`, stacked on #8444).
  `SentryDataCategory` → Swift `@objc @_spi(Private) enum: UInt` (17 cases, raw values preserved incl.
  the unused-but-kept ones). `SentryDataCategoryMapper` **ported to Swift**: mapping lives on the enum
  (`name`, `init(itemType:)`, `init(name:)`); ObjC callers use `@objc SentryDataCategoryMapper` class
  methods, Swift callers use native initializers. This was needed because Swift production code
  (`DefaultRateLimits`, `RateLimitParser`, `SentryFileManager`) calls the enum-returning mapper funcs,
  which a forward-declared (incomplete) enum can't satisfy — a wrinkle `SentryDiscardReason` didn't hit.
  Verified: iOS+macOS build ✅, analyze ✅, 72 transport/rate-limit tests ✅, digest regenerated.
  **Next: rebase A2 (#8443) to the real enum types once #8444 + #8451 merge; then A3.**
- 2026-07-16: **#8451 CI shakeout.** First full run surfaced a real regression — 115 failures in
  `ConcurrentRateLimitsDictionaryTests.testConcurrentReadWrite`: it fabricated categories from raw values
  100/200/300, valid under the open ObjC enum but `nil` under the closed Swift enum. Fixed to use real
  `SentryDataCategory.allCases`. Second run's remaining "failures" were all the draft `ready-to-merge`
  gate cascade (real matrices `skipping`) — not real; the Fast lane + Lint + API Stability all passed.
- 2026-07-16: **A2a1 (#8444) MERGED to `main`** as `bacd00766`. **A2a2 (#8451) rebased onto fresh `main`**
  (dropped the now-redundant discard-reason commits; `git rebase --onto origin/main b15415597`). Clean,
  no conflicts; digest re-verified zero-diff against the new baseline (838 additive lines, DataCategory
  only). PR #8451 now `mergeable`, blocked only by the label gate. Backups: `backup/data-category-*`.
  **Next real work: A2 (#8443) rebase + retype to real enums (see "DO THIS NEXT" at top).**
- 2026-07-16: **A2a2 (#8451) close-reviewed + refined** (subagent + manual, all clean — behavior-parity
  with the old ObjC mapper verified case-by-case, incl. the Relay `profile_chunk→profile_chunk_ui` /
  `statsd→metric_bucket` remaps). Three user-requested refinements applied (folded into the conversion
  commit; digest unchanged since none are `@objc`):
  1. **`init(itemType:)` moved to its own extension file** `SentryDataCategory+EnvelopeItemType.swift`
     (it couples the enum to `SentryEnvelopeItemTypes` — a different domain). Core `SentryDataCategory.swift`
     is now purely intrinsic. Matches the repo's `Type+Feature.swift` convention.
  2. **Deduped the `SentryDataCategory(rawValue:) ?? .unknown` pattern** (was in 5+ places) into a single
     non-failable convenience init `init(_ rawValue: UInt)` on the enum; all call sites + the mapper's
     `category(forNSUInteger:)` now use `SentryDataCategory(x)`. (Can't override the synthesized failable
     `init(rawValue:)`, so the unlabeled `init(_:)` is the form that works.)
  3. **Reverted `ConcurrentRateLimitsDictionaryTests.testConcurrentReadWrite` to the original structure**
     (kept the `getCategory` helper + a/b/c/d + loop shape verbatim); ONLY changed `loopCount 10→4` and
     offsets `100/200/300→4/8/12` so fabricated raw values stay in the closed enum's 0–15 range.
     Verified: iOS+macOS build, analyze, 175 tests (0 fail), digest zero-diff. Added a 2-sentence note to the
     #8451 description explaining the `sdk_api*.json` additions are expected (digester tracks `@objc` enums).
- 2026-07-16 (EOD): **A2a1 (#8444) confirmed MERGED** (`2026-07-16T11:42Z`). #8451 is the next merge, then
  A2 (#8443). Paused here for the day — resume at "RESUME TOMORROW" at the top of this doc.
- 2026-07-20: **A2a2 (#8451) MERGED to `main`** as `487d99372` (`2026-07-20T07:49Z`). Before merge:
  applied user feedback — dropped the "like/matching the original Objective-C mapper" justifications from
  `SentryDataCategory.swift` comments and tightened the `userFeedback` note (`docs: refine SentryDataCategory
  comments`); kept the `ConcurrentRateLimitsDictionaryTests` `4/8/12`/`loopCount 4` numbers (reverting to the
  old `100/200/300` is impossible under the closed 17-value Swift enum); shortened the PR description to a
  1-line "diff looks large but is small" note + 2 sentences. User merged main into #8451, then babysat CI:
  all failures were a single Cirrus-runner flake (UI Tests Common couldn't download the prebuilt
  `*.xcframework.zip` artifacts → `fatalError` before any test ran; upstream builds all green, bitrise mirrors
  of the same configs passed). Re-ran once → **fully green (260 pass), approved, merged.**
  **Merged `origin/main` into this tracker branch** (`c8f60a11f`): the stale pre-enum A2 WIP (`565aac5f3`)
  conflicted in `TestTransport.swift`, `SentryHttpTransport.m`, `SentryTransportAdapter.h`, and
  `SentryTransport.h` (deleted here, still present in `main` since A2/#8443 hasn't merged) — all resolved in
  favor of `main` (WIP discarded, as intended; this branch is plan-only). **All three enum/protocol
  prerequisites (A1, A2a1, A2a2) are now in `main`. Next real work: A2 (#8443) rebase + retype to the real
  enums, then A3.**
- 2026-07-21: **A2 (#8443) re-landed with the real enum types.** Chose a **fresh re-apply** over a rebase:
  reset `ref/convert-transport-protocol-to-swift` to `origin/main` and applied the change clean. Because the
  enums were already Swift `@objc @_spi(Private)` in `main`, the ObjC conformers' enum-typed `recordLostEvent`
  needed **no change** — the whole `NSUInteger`/`.rawValue` layer from the stale commit was obsolete. Real
  change (21 files): new `Sources/Swift/Networking/SentryTransport.swift` (`Transport` protocol +
  `SentryFlushResult: Int`, `recordLostEvent` typed to the real enums); deleted `include/SentryTransport.h`;
  `kSentryFlushResult*`→`SentryFlushResult*`; conformer headers import `SentrySwift.h`, reference-only headers
  forward-declare `@protocol SentryTransport;`; 6 pbxproj refs dropped; test `sut`→`Transport`.
  **One plan miss caught by the build:** `TestTransport.swift` DID need editing — a plain `public` class can't
  conform to the now-SPI `Transport` or return the now-SPI `SentryFlushResult`, so it became
  `@_spi(Private) public` (kept enum-typed `recordLostEvent`, no `.rawValue`). Verified: iOS+macOS build ✅,
  analyze ✅, **299 tests** (81 transport/factory/flush + 218 TestTransport-consumer) 0 failures ✅,
  `make generate-public-api` → additive `SentryFlushResult` only in `sdk_api.json` + `sdk_api_v10.json`.
  **No force-push (user request):** landed the clean commit (`75c658c38`, backup branch `backup/a2-real-enums`)
  onto #8443 via a **merge of `origin/main` into the stale branch** with the merged tree forced to the verified
  clean tree (merge `8f42b43ba`), pushed fast-forward. PR #8443 `MERGEABLE`, still draft. **Next: A3 once #8443
  merges.** Note `check-versions` pre-commit hook fails locally on an unrelated `xcodegen` 2.45.4-vs-2.46.0
  drift — skipped via `SKIP=check-versions`; the real format/lint hooks all passed.
- 2026-07-23: **Confirmed A2 (#8443) merged** to `main` (2026-07-21T09:50:46Z) — verified via
  `gh pr view 8443`. All four prerequisites (A1, A2a1, A2a2, A2) are in `main`. **Merged `origin/main`
  into this tracker branch** (merge `05d67ba50`, no force-push, plain `git merge`). Exactly one
  conflict, exactly as this doc predicted: `Sources/Swift/Networking/SentryTransport.swift` (add/add —
  this branch's stale pre-enum WIP vs. the real A2 file merged into `main`); resolved by taking
  `origin/main`'s version verbatim, discarding the stale WIP. 151 other files changed cleanly
  (auto-merged or unrelated additions from `main`'s forward progress — Synchronized helper,
  AssociatedObjectAccessor, view-hierarchy refactor, etc. — none touch spotlight/transport code).
  Post-merge `make build-ios` failed on **expected fallout**: `SentrySpotlightTransport.m`'s
  `recordLostEvent` was still `NSUInteger`-typed, but the merged `Transport` protocol now requires the
  real enum types (`SentryDataCategory`/`SentryDiscardReason`) — the exact same fix A2 already applied
  to `SentryHttpTransport.m`. Applied the matching one-line-per-method retype. This is merge-conflict
  resolution, **not** A3 — the class is still ObjC (`SentrySpotlightTransport.{h,m}` unchanged in
  shape) and its test still passes `dispatchQueueWrapper:`. Verified: `make build-ios` ✅, 84 tests
  (`SentrySpotlightTransportTests` + `SentryHttpTransportTests` + `SentryTransportFactoryTests`) ✅.
  **Nothing pushed yet — paused for user confirmation before committing/pushing.** A3 (the actual
  class conversion) is now the only remaining phase; see "RESUME HERE — A3" above.
