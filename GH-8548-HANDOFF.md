# GH-8548 — Deferred UIViewController swizzling: WIP handoff

Branch: `fix/deferred-uiviewcontroller-swizzling` (off `origin/main`, standalone — not stacked on #8457).
Status: **implementation complete and validated; committed and pushed; draft PR #8625 open.**

## Problem

Issue **#8548** tracks a residual crash from **#8152**. The SDK's `UIViewController` performance
auto-instrumentation eagerly discovers every `UIViewController` subclass at SDK start and swizzles
it. Discovery/swizzling **realizes** the class. Realizing a Swift `UIViewController` subclass that is
`@available`-gated to a newer OS and stores a gated newer-framework type (e.g.
`RoomPlan.CapturedStructure?`) runs the Swift type-metadata completion function and jumps to null — an
uncatchable `SIGSEGV` on OS versions below the gate. Confirmed on the iOS 16.4 simulator.

## Fix

Add a **deferred first-instantiation** swizzle path, behind a new opt-in **experimental** option
`options.experimental.enableUIViewControllerInitSwizzling` (default **false**):

- Swizzle only the two base `UIViewController` designated initializers
  (`initWithNibName:bundle:` + `initWithCoder:`).
- In each replacement: call the original init **first**, read the concrete class from the returned
  object via `object_getClass`, then **synchronously** hand it to a handler that runs the existing
  filter + per-subclass lifecycle swizzle. Return the original result verbatim.
- A never-instantiated gated subclass is never swizzled → never realized below its gate → no crash.
  Every view controller the app actually uses still gets full instrumentation.

**Why synchronous (no dispatch hop):** a live instance must have its lifecycle methods swizzled
immediately after init; an async hop would leave a window where the instance exists but isn't
instrumented. GH-1355 (see below) is avoided by ordering (original first), not by leaving the init
frame.

**Flag off (default):** behavior is unchanged — the existing eager `SentrySubClassFinder` image scan
runs. Flag on: the funnel runs and the eager scan is skipped. Both paths stay live; nothing deleted.

### Key historical constraint — GH-1355 / #1361

The SDK removed init swizzling in **#1361** because the old approach crashed apps using a
convenience/custom initializer on iOS 15 (`NSInternalInconsistencyException: UIViewController is
missing its initial trait collection…`). Root cause: the old code mutated the subclass's method list
_from inside_ the initializer, before the original ran. The new funnel is defensively different:
original-first, `object_getClass(result)` (a C call, not a message to `self`), and it swizzles only
the **base** class (so `class_replaceMethod` replaces, never adds a method to a subclass).

### Why not the typed Swift swizzle API (PR #8524)

`SentryTypedSwizzle` (added in #8524) is now the preferred path for new Swift-owned swizzles, but its
only object-returning overloads model **+0 autoreleased** returns (`URLSessionDataTask`). An
initializer returns **+1** (`ns_returns_retained`), which the typed API does not support, and there is
no init-family/generic-object overload. We deliberately use the ObjC `SentrySwizzleInstanceMethod`
macro — the audited mechanism already used for `NSData`'s init swizzle. This is documented in the
helper `.m` NOTE.

## Files changed

Core:

- `Sources/Sentry/SentryUIViewControllerSwizzlingHelper.m` / `include/…​.h` — the init funnel
  (`+swizzleUIViewControllerInitsWithSubclassHandler:`), handler storage, `+stop` clears it,
  `+unswizzle` restores both init IMPs.
- `Sources/Swift/Core/Integrations/Performance/SentryUIViewControllerSwizzling.swift` — flag-gated
  `start()`; `handleInstantiatedViewController` router; lock-free main-thread `NSMutableSet`
  (`processedClasses`); root-hierarchy walk routes through the same entry point.
- `Sources/Swift/SentryExperimentalOptions.swift` — new `enableUIViewControllerInitSwizzling = false`.
- `Sources/Swift/Helper/SentryEnabledFeaturesBuilder.swift` — telemetry entry
  `"uiViewControllerInitSwizzling"`.
- `sdk_api.json` / `sdk_api_v10.json` — regenerated for the new public option. (ObjC mirror
  intentionally NOT updated — matches `enableStandaloneAppStartTracing`, which is also unmirrored.)

Tests:

- `Tests/…​/SentryUIViewControllerSwizzlingTests.swift` — 5 funnel tests (once-per-class, filters,
  never-instantiated, dedup, flag-off-uses-finder) + test hooks
  (`testHandleInstantiatedViewController`, `testHasProcessedViewController`).
- `Tests/…​/SentryUIViewControllerSwizzlingHelperTests.swift` — 2 funnel tests (synchronous handler,
  no-call-after-stop).

Sample (iOS-Swift) — crash-repro fixtures + enabling the flag:

- `App/Sources/ViewControllers/SubClassFinderRegressionViewController.swift` (NEW) — 3 gated fixtures
  (#8548 Repro A). Ported from #8457 with the `swizzleClassNameExcludes` workaround **removed** so they
  run through the real swizzle path.
- `App/Sources/ViewControllers/ConvenienceInitViewController.swift` (NEW) — GH-1355 forward-guard
  (`UITableViewController`, convenience + designated init, no `@objc`).
- `UITests/Sources/SubClassFinderRegressionUITests.swift` (NEW) — 3 UITests covering both fixtures.
- `App/Sources/AppDelegate.swift` — enables `experimental.enableUIViewControllerInitSwizzling = true`
  via `SentrySDKWrapper.additionalOptionsConfiguration`.
- `App/Sources/ExtraViewController.swift` + `App/Resources/Base.lproj/Main.storyboard` — buttons to
  reach both fixtures from the Extra tab.
- `Samples/SentrySampleShared/.../SentrySDKWrapper.swift` — `additionalOptionsConfiguration` hook.
- `CHANGELOG.md` — Features entry under `## Unreleased`.

## Validation done (all green)

- `make format`, `make analyze`, `make build-ios`, `make build-macos` — clean.
- Unit: 36 `SentryUIViewControllerSwizzlingTests` + 13 `SentryUIViewControllerSwizzlingHelperTests`
  pass (iPhone 16 Pro / iOS 18.6).
- Sample UITests (`SubClassFinderRegressionUITests`, 3 tests) pass with the funnel active on **iOS
  16.4** (Repro A gated crash) and **iOS 15.5** (Repro B convenience-init).

### GH-1355 red proof — still unreproducible after a dedicated deep dive

To prove the `ConvenienceInitViewController` fixture is a genuine crasher, I temporarily wired the old
crash-inducing swizzle ordering and ran on iOS 15.5. It **did not crash** in any combination tried:
plain `UIViewController` (Debug), `UITableViewController` (Debug + Release), on both iPhone 13 and
iPhone 11. iOS 15.0 isn't installable on this host
(`simctl`: "not supported on hosts after macOS 14.99.0"). The fixture is kept as an honest **forward
regression guard**, not a proven reproduction. The temporary naive-ordering hack was fully reverted
(helper `.m` is the safe funnel).

#### Second, deeper attempt (standalone probe, no SDK) — also negative

A standalone probe (`/tmp/gh1355/repro.swift`, throwaway) reimplemented **both** orderings with zero
Sentry code, using the exact `CustomTableViewController` from the GH-1355 thread (convenience init →
custom designated init → `super.init(style:)`, no `@objc`):

- **old ordering** — message `self` and mutate the subclass method list _before_ calling the original
  init (pre-#1361 behavior, `git show 75e72817a20aa5adc35155045e1ead4d53a8624a`).
- **new ordering** — original init first, then `object_getClass(result)` (this PR's funnel).

It exercised the reporters' shapes: `UINavigationController` push, a **second instance** of the same
subclass (AndrewSB crashed on the second page), and a `UIPageViewController` swapping pages.

**Result: NO-CRASH in every combination** — orderings {old, new} × iOS {15.5 iPhone 13 Pro, 15.5
iPhone 13, 18.6, 26.4}.

Crucially, the probe **verifies it actually triggers the blamed mechanism** rather than silently
missing it. Instrumented output confirms the lifecycle swizzle `ADDED` (not replaced) all six methods
to the Swift subclass, `class_replaceMethod` returning `nil`:

```
PROBE swizzle CustomTableViewController.viewDidLoad directlyImplemented=false replaceReturnedNil=true -> ADDED
… viewWillAppear:, viewDidAppear:, viewWillLayoutSubviews, viewDidLayoutSubviews, viewWillDisappear: — all ADDED
PROBE swizzle UIViewController.viewDidLoad directlyImplemented=true replaceReturnedNil=false -> REPLACED
```

So "adds a method to a subclass that doesn't implement it" — the mechanism #1361's description blamed
— is **reproducible on demand and is not sufficient to cause the crash** on any OS available here.

**Historical record, corrected.** #1361's description reads as a root cause, but the issue thread
shows it was a hypothesis: the maintainer reproduced the same `NSInternalInconsistencyException` in an
**empty sample project with no Sentry SDK at all**, filed it at
<https://developer.apple.com/forums/thread/691371>, and merged #1361 saying "we decided to merge and
release #1361 even if it wouldn't fix this issue." Reporters confirmed `@objc` on the designated init
worked around it, and that it reproduced **only via TestFlight/Release, never in Debug** on the same
device and commit. Best available reading: an iOS-15.0-era UIKit bug that swizzling perturbed, not a
defect the SDK's ordering caused.

**What this does and does not license.** It does _not_ prove the current funnel is safe on iOS 15.0
hardware — that OS is untestable here. It does mean the "adds a method mid-init" objection cannot be
demonstrated as a crasher on 15.5+ even when deliberately provoked. Anyone revisiting this should
weigh an actual iOS 15.0 device test before treating the in-init-frame swizzle as proven-unsafe or
proven-safe.

> Rejected direction: dispatching the subclass swizzle **async onto the main queue** to leave the
> initializer frame. Racy — it opens a window where a live instance exists uninstrumented, and it can
> reorder against the instance's own first `viewDidLoad`. Not pursued.

## Transaction-equivalence validation (DONE — result: identical)

Confirmed the funnel produces the same auto-instrumentation as the default path, by comparing the
`ui.load` transactions the SDK would send with the flag **off** (eager `SentrySubClassFinder`) vs
**on** (funnel). Full result + copy-paste re-run instructions are in the **PR #8625 description**
(collapsible "Transaction-equivalence regression check" section). Summary:

- Method: drive the iOS-Swift sample through the same navigation twice, with the SDK forced offline
  (`--io.sentry.disable-http-transport` → `SentryQueueableRequestManager.isReady` returns `NO` in
  DEBUG, so every envelope is cached to disk instead of uploaded). Compare the cached envelopes.
- Result: **identical** — both runs produced the same 6 `ui.load` transactions
  (Errors/Transactions/Profiling/Extra/SubClassFinderRegression/ConvenienceInit), same span-op
  composition, same span descriptions, same `origin=auto.ui.view_controller`. `diff` is empty.
- The throwaway harness used for this (a `deferSwizzling` sample override, release/tag stamping, and a
  `VCSwizzleComparisonUITests`) has been **deleted** — this was a one-time check, not a shipped test.
- Gotcha: the iOS 16.4 sim on this host would not reliably foreground the sample app, so its `ui.load`
  transactions never finished (0 envelopes). The **iPhone 16 Pro / iOS 18.6 sim worked reliably.**

## CI failure: leaked init funnel across test suites (FIXED)

The first CI run failed **Fast Unit Tests (iOS 18)** — not the `run-full-ci` label gate. Two suites
crashed with a Swift trap:

- `SentryViewHierarchyProviderTests.test_ViewHierarchy_with_ViewController` — `viewController.view`
  came back nil at `SentryViewHierarchyProviderTests.swift:273`.
- `UserFeedbackIntegrationTests.testFeedbackForm_whenLocalConfigurationIsSet_shouldApplyToCurrentFormOnly`
  — trapped in `SentryUserFeedbackFormController.commonInit()`.

Proven a real regression from this branch, not a flake: `main` passes the four suites together (98
tests, 0 failures); the branch failed them. Each suite passes **in isolation** — only the combination
fails, which is why per-suite runs looked green.

Cause: `SentryUIViewControllerSwizzlingTests` tears down via `clearTestState()`, which never called
`SentryUIViewControllerSwizzlingHelper.stop()`, so the base-`UIViewController` init funnel stayed
installed and leaked into later suites. `SentryUIViewControllerSwizzlingHelperTests` was unaffected
because it calls `stop()` in its own `tearDown`. Commit `9876a5ca3` ("drop init unswizzling") made it
worse by removing the only mechanism that restored the base init IMPs — its rationale ("harmless
because stop clears the handler") doesn't hold when nothing calls `stop()`.

Fix (three parts — adding `stop()` to `clearTestState` alone is **not** sufficient):

- `Sources/Sentry/SentryUIViewControllerSwizzlingHelper.m` — restored the two init
  `SentryUnswizzleInstanceMethod` calls in the test-only `+unswizzle`, keyed by selector to match the
  install keys; corrected the stale comment claiming the funnel "stays installed".
- `SentryTestUtils/Sources/ClearTestState.swift` — calls `SentryUIViewControllerSwizzlingHelper.stop()`
  in the UIKit block. Needed `import _SentryPrivate`: the helper ships in `SentryPrivate.h`, so it is
  **not** reachable through `@testable import Sentry` alone.
- `…/SentryUIViewControllerSwizzlingHelperTests.swift` — regression test asserting both base
  initializers are swizzled after install and restored after `stop()`, detected via
  `imp_getBlock(class_getMethodImplementation(...))` (non-nil only for an
  `imp_implementationWithBlock` IMP).

Verified: the four-suite run now reports **113 tests, 0 failures** (98 from main + 15 new on this
branch). `make format` and `make analyze` clean.

## Thread safety: reviewed, no change needed

A review flagged `processedClasses` (unlocked `NSMutableSet`) and `_initHandler` as races. Both writes
are already main-thread-confined **by construction**, not by convention:

- install — `SentrySDKInternal.m:254` wraps `installIntegrations` in
  `dispatchAsyncOnMainQueueIfNotMainThread`.
- uninstall — `SentrySDKInternal.m:588` (`+[SentrySDKInternal close]`) wraps the whole teardown,
  including `removeAllIntegrations` → `uninstall` → `swizzling.stop()`, in `dispatchSyncOnMainQueue`.

Decision: do **not** add locking. If this is revisited, `SentryDispatchQueueWrapper` already offers
`dispatchAsyncOnMainQueueIfNotMainThread` / `dispatchSyncOnMainQueue`.

## iOS 15 real-device probe split out into PR #8667 (draft, stacked)

The temporary SauceLabs probe that ran the GH-1355 fixture under the pre-GH-1361 ordering on real iOS
15 hardware **is no longer on this branch**. It lives in draft PR **#8667**
(`test/gh1355-ios15-saucelabs-probe`), based on this branch so its diff is only the probe:
`benchmarking.yml` (branch trigger + matrix entry), `.sauce/benchmarking-config.yml` (GH-1355 iOS 15
suite + class scoping of the existing suites), `Benchmarking/Sources/GH1355OldOrderingTests.m`, and the
`useOldCrashingOrdering` launch-argument branch in `SentryUIViewControllerSwizzlingHelper.m`.

Split out because SauceLabs was busy and the probe's failures were blocking this PR's CI. **Do not
merge #8667** — read its result, then close it. This branch was force-pushed to drop the four probe
commits (safe: no reviews existed). Probe state is preserved in the local branch
`backup/probe-state-9e5a56b18`.

Repo gotchas learned while wiring it up, worth knowing independently:

- `iOS-Swift-UITests` is a **target, not a scheme**. The `build_ios_swift_ui_test` fastlane lane builds
  `-scheme iOS-Swift-UITests`, which doesn't exist — the lane is dead code that fails for any caller.
  UI tests run through the `iOS-Swift` scheme; one `build-for-testing` on it emits both the app and
  `iOS-Swift-UITests-Runner.app`.
- Signing and building must be in the **same** fastlane lane: every signing lane ends with
  `delete_keychain`, so a later `xcodebuild` step fails with `No signing certificate found`.
- `setup_code_signing` uses `readonly: false` and **generates** profiles in the shared Match repo —
  don't call it from CI.
- The sample's `Test` configuration defines `SENTRY_TEST=1`, **not `DEBUG`**
  (`Samples/Shared/Config/ClangPreprocessing.xcconfig`). A `#if DEBUG` gate silently compiles out and
  produced a false green until gated on `DEBUG || SENTRY_TEST || SENTRY_TEST_CI`.
- The pre-existing SauceLabs benchmark suites had **no class filter**, so they run every XCTestCase in
  the target. Adding one class pushed them past the 60m timeout;
  `ERR Suite failed. error="User Abandoned Test -- User terminated"` means **timeout**, not assertion
  failure.

## Deferred (non-blocking, still open)

1. **Changelog is missing the PR number** — Danger fails with "Please consider adding a changelog
   entry". The entry exists under `## Unreleased` → Features but omits `(#8625)`, which Danger
   requires. One-line fix.
2. **ObjC mirror missing** — `enableUIViewControllerInitSwizzling` is absent from
   `Sources/SentryObjC/Public/SentryObjCExperimentalOptions.h` and
   `Sources/SentryObjCCompat/SentryObjCExperimentalOptions.swift`, so pure-ObjC consumers can't enable
   the fix. Note `enableStandaloneAppStartTracing` is **also** unmirrored, so there is precedent either
   way; decide whether to mirror just this one, both, or neither (and document the reason).
3. **`run-full-ci` label** — applied.
4. **Delete this handoff file before merge** — it is agent scratch, not maintainer docs. The durable
   content lives in the PR description and code comments.
   Also close (don't merge) **PR #8667**, the stacked iOS 15 probe.
5. **Don't close #8548 with this PR** — the option defaults to **off**, so default-configuration users
   remain exposed. Reference the issue; close it when the default flips.

## How to pick this up

1. `git checkout fix/deferred-uiviewcontroller-swizzling` (rebase on `origin/main` if it moved).
2. Re-run the verification loop: `make format` → `make analyze` →
   `make build-ios FOR_AGENTS=true IOS_DEVICE_NAME="iPhone 16 Pro" IOS_SIMULATOR_OS=18.6` →
   `make test-ios … ONLY_TESTING=SentryTests/SentryUIViewControllerSwizzlingTests` (and the helper
   suite). Sim override is required on this host (default sim absent).
3. Re-run the sample UITests on iOS 16.4 and 15.5 (target the 15.5 device by **UDID** — the device
   name includes the OS suffix, so `name=iPhone 11` won't match):
   `xcodegen --spec Samples/iOS-Swift/iOS-Swift.yml` then
   `xcodebuild test -project Samples/iOS-Swift/iOS-Swift.xcodeproj -scheme iOS-Swift
   -destination 'platform=iOS Simulator,id=<UDID>'
   -only-testing:'iOS-Swift-UITests/SubClassFinderRegressionUITests'`.
4. The draft PR #8625 is open with the transaction-equivalence report. Remaining before marking ready:
   confirm CI is green and resolve the open decisions below.

## Open decisions for the PR

- Whether to close #8548 now (opt-in, default off → default behavior unchanged) or when the default
  flips in a future major. Current recommendation: **don't close it** (see Deferred #5).
- Whether to keep this handoff file in the repo or delete it before merge. Current recommendation:
  **delete** (see Deferred #4).
- **Open review objection, unresolved:** the per-subclass lifecycle swizzle still runs inside the
  outermost initializer frame, and `class_replaceMethod` **adds** the method when the subclass doesn't
  implement it — so the PR's "only mutates the base class" wording is inaccurate and should be
  corrected regardless. The deep dive above could not demonstrate this as a crasher on any testable
  OS, and the async-hop remedy was rejected as racy. If a reviewer still wants the in-init mutation
  gone without an async hop, the remaining option is a **replace-only guard**: skip the swizzle unless
  the subclass implements the selector directly (`class_copyMethodList` check), trading some span
  coverage for never adding a method mid-init.
