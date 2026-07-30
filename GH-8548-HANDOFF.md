# GH-8548 — Deferred UIViewController swizzling: WIP handoff

Branch: `fix/deferred-uiviewcontroller-swizzling` (off `origin/main`, standalone — not stacked on #8457).
Status: **implementation complete and green; one deferred validation step remains before opening a PR.**
Nothing is committed yet.

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

### GH-1355 red proof — inconclusive (documented limitation)

To prove the `ConvenienceInitViewController` fixture is a genuine crasher, I temporarily wired the old
crash-inducing swizzle ordering and ran on iOS 15.5. It **did not crash** in any combination tried:
plain `UIViewController` (Debug), `UITableViewController` (Debug + Release), on both iPhone 13 and
iPhone 11. This matches the historical record — GH-1355 was iOS-15.0 / device / TestFlight-Release
specific and never root-caused (an Apple UIKit bug; `@objc` on the init worked around it). iOS 15.0
isn't installable on this host. The fixture is kept as an honest **forward regression guard**, not a
proven reproduction. The temporary naive-ordering hack was fully reverted (helper `.m` is the safe
funnel).

## REMAINING STEP (deferred — do before opening the PR)

**Transaction-equivalence validation** — confirm the funnel produces the same auto-instrumentation
transactions as the default path. User-approved approach:

1. Run the iOS-Swift sample **twice** against its Sentry project (DSN `o447951/5428557`), navigating
   the **same** screens each time:
   - Run A: flag **off** (default eager path).
   - Run B: flag **on** (funnel).
2. Distinguish the runs with a **scope tag `init_swizzling = enabled|disabled`** (wire via the
   sample's `additionalOptionsConfiguration` / a scope callback in `SentrySDKWrapper`).
3. Use the **Sentry MCP** (`search_events` / `get_event`) to pull both sets of `ui.load` transactions
   and compare operation, description, and span tree.
4. Deliverable: a **one-time before/after report in the PR description** (transaction lists without
   vs with the change, showing equivalence). NOT a permanent test.

Reference infra that already exists: `LaunchVCTransactionCapture` (in-process `spanCaptureHandler` →
marshaled text field) and `LaunchProfilingVCTransactionUITests` show how VC spans are captured/asserted
in the sample.

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
4. Do the transaction-equivalence validation (above) and write the PR report.
5. Open the PR: title `feat: defer UIViewController swizzling to first instantiation`, body "Fixes
   #8548", include the transaction report. Only push/open the PR when explicitly asked.

## Open decisions for the PR

- Whether to close #8548 now (opt-in, default off → default behavior unchanged) or when the default
  flips in a future major.
- Whether to keep this handoff file in the repo or delete it before merge.
