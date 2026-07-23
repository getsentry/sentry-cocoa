# Handoff: `SentrySubClassFinder` availability crash (GH #8152) — remaining work

> PR [#8457](https://github.com/getsentry/sentry-cocoa/pull/8457), branch
> `fix/subclassfinder-availability-crash`. This note only tracks what's left. The fix mechanism and
> the rationale for the open limitations live in the code comments
> (`SentryDefaultImageClassProvider.swift`, `SentrySubClassFinder.swift`, and the `actOnSubclassesOf`
> call site in `SentryUIViewControllerSwizzling.swift`). Not part of the shipped SDK.

## Open limitations (deferred crash edge cases)

Full detail in `REVIEW-PR-8457.md`. Both are accepted, documented, and to be fixed later:

- **Finding 4 — gated VC subclass still crashes at swizzle time.** The headline fix is incomplete: a
  Swift VC subclass gated to a newer OS with a gated stored-property type still crashes on older OSes
  (confirmed iOS 16.4; repro = the committed `SubClassFinderRegressionViewController` + UITest). The
  fix is designed but not implemented — see "Deferred fix design" below. Two guard spikes already
  tried and rejected — don't re-spike (see `REVIEW-PR-8457.md`).
- **Finding 2 — unremapped raw `__objc_classlist` pointers** reach the swizzler; can double-swizzle a
  remapped class. Narrow. Fix without reintroducing the GH-8152 realization crash. (Resolved for free
  by scope Option 1 below.)

## Deferred fix design: swizzle at first instantiation (Finding 4)

Designed 2026-07-23; not implemented. Timing decision (dispatch_async, below) is made; the scope
decision (Option 1 vs 2) is still open.

### Why swizzling cannot avoid realization

Answered definitively: no. Three realization triggers in the swizzle path, in order —
`SentrySwizzle.m` dedup `[swizzledClasses containsObject:]` (messages the class →
`lookUpImpOrForward` → `realizeClassMaybeSwiftMaybeRelock`; matches the confirmed crash stack),
`class_getInstanceMethod` (`SentrySwizzle.m` `swizzle()`), and `class_replaceMethod`. Swizzling
mutates the runtime-allocated method list (`class_rw_t`), which only exists after realization — this
is a hard ObjC runtime constraint, not fixable inside our swizzling logic. And there is no safe
"is this class unavailable?" probe: the realized-bit guard zeroes coverage and the
`swift_checkMetadataState` probe itself crashes (both empirically rejected; see `REVIEW-PR-8457.md`).

### History: this approach was tried and reverted in 2021 (GH-1355 / #1361)

Pre-#1361 (`git show 75e72817a~1:Sources/Sentry/SentryUIViewControllerSwizziling.m`), the SDK
swizzled base `UIViewController` `initWithCoder:` + `initWithNibName:bundle:` and, inside the
replacement, ran `swizzleViewControllerSubClass:[self class]` **before** `SentrySWCallOriginal`. On
iOS 15 that crashed apps using Swift convenience initializers:
`NSInternalInconsistencyException: UIViewController is missing its initial trait collection
populated during initialization`. The old code messaged `self` and mutated the class mid-init,
before UIKit's designated init ran. Root cause was never definitively pinned (#1361 commit message
says "It seems like…"), so the new design must be defensively different, not just tweaked. Second
constraint: GH-1366 — subclass lifecycle swizzling must run on the **main thread**.

### Funnel design

- Swizzle base `UIViewController` `initWithNibName:bundle:` + `initWithCoder:` (its two designated
  inits; `-init` routes through the former; all subclass designated inits reach one via super). The
  base class implements both, so `class_replaceMethod` **replaces**, never adds — the "adds override
  to a class that doesn't implement it" concern from #1361 doesn't apply at the funnel level.
  `SentrySwizzleModeOncePerClassAndSuperclasses` with static keys (re-`start()` safe). Implemented in
  `SentryUIViewControllerSwizzlingHelper.m` with a handler block set from Swift; handler cleared in
  `+stop`.
- **Replacement order is load-bearing** (all three points differ from the 2021 code):
  1. First statement: `SentrySWCallOriginal(...)`. Never touch `self` before it.
  2. Use `object_getClass(result)` on the **returned** object — a C call, not a message; handles
     init-family self-replacement and nil returns.
  3. `dispatch_async` onto the main queue to run the existing filter + swizzle path
     (`shouldSwizzleViewController` → `SentryUIViewControllerSwizzlingHelper
     swizzleViewControllerSubClass:` in `SentryUIViewControllerSwizzling.swift`). **Decided:** async
     over sync-after-init — the class mutation happens fully outside any init frame, maximally
     distant from the GH-1355 shape. Accepted cost: a VC inited and pushed in the same runloop tick
     may lose its _first_ instance's spans (subsequent instances covered). Also satisfies GH-1366
     for off-main inits.
- **Fast path:** lock-guarded `NSMutableSet` of processed classes (accepted AND rejected) in
  `SentryUIViewControllerSwizzling`, checked before any string filtering; mark **before** the async
  hop so it can't double-process. Steady-state per-init cost: one lock + one set lookup.
  `SentrySwizzle`'s own `OncePerClass` dedup stays as second line of defense.
- **Why it's safe:** the handler only ever sees classes with a live instance → fully realized. Gated
  classes are never instantiated on unsupported OSes → never swizzled → no crash; full coverage
  otherwise. Bonus: `object_getClass(instance)` is always the live, remapped class pointer — the
  funnel is immune to Finding 2 by construction.
- **Tracker semantics confirmed safe:** spans are created lazily per instance at
  `loadView`/`viewDidLoad` (`startRootSpanFor:` in `SentryDefaultUIViewControllerPerformanceTracker.m`);
  appear/disappear hooks pass through when no span exists. A class swizzled between init and view
  loading gets full instrumentation. `swizzleLoadView:`'s IMP-comparison skip behaves identically at
  first-instantiation time.
- **stop()/uninstall:** funnel replacements no-op through to the original when the static weak
  `_tracker` is nil (existing helper pattern); handler block cleared in `+stop`. Test-only
  `+unswizzle` can restore both base init IMPs (static keys make that possible, unlike the
  per-subclass lifecycle swizzles).
- **ARC note:** `imp_implementationWithBlock` doesn't get init-family `ns_returns_retained`
  semantics; the plain pass-through is balanced via the `objc_autoreleaseReturnValue` handshake and
  shipped in exactly this shape pre-2021. Optional hardening: annotated function-pointer cast
  (`ns_consumed` self, `ns_returns_retained`) — verify clang accepts it on the block before keeping.
- Pre-SDK-start instances stay covered by the existing `swizzleRootViewControllerAndDescendant` +
  `UIScene.willConnectNotification` path.

### Scope decision (OPEN — pick one when implementing)

Keeping eager discovery **active** is not an option in either variant — realizing gated classes at
SDK start _is_ the crash.

- **Option 1 — full replacement (agent-recommended):** delete `SentrySubClassFinder.swift`, the
  `SentryImageClassProvider`/`SentryDefaultImageClassProvider` pair (verify no other consumers;
  `SentryDependencyContainer.imageClassProvider` exists only to feed the finder), the image loop in
  `start()`, `swizzleUIViewControllersOfClassesInImageOf`, and `SentrySubClassFinderTests`. Resolves
  Findings 1 (image-unload race), 2 (unremapped pointers), and 4 in one move. Known small coverage
  regression to flag in the PR: a VC inited _before_ SDK start but not in the root hierarchy at
  start is no longer instrumented (matches pre-2021 behavior).
- **Option 2 — minimal reroute:** stop invoking the finder from `start()` and add the funnel; leave
  the finder files, DI plumbing, and `SentrySubClassFinderTests` as dead-but-compiling code; delete
  in a follow-up PR. Smaller diff on an already-long branch.

### Test plan (condensed)

- Funnel swizzles exactly once (IMP of `viewDidLoad` changes after first init, no rework on second).
- Filters applied: `swizzleClassNameExcludes` and not-in-app classes stay unswizzled.
- **Never-instantiated class is never swizzled** — the unit-level regression test for the eager
  path's removal (a truly `@available`-gated crasher can't run in a unit test on a current sim).
- Main-thread guarantee via `TestSentryDispatchQueueWrapper` for off-main inits.
- `stop()` semantics: post-stop inits don't swizzle; no spans.
- `initWithCoder:` path (storyboard / `NSKeyedUnarchiver`).
- Breakage inventory: `TestSubClassFinder`-based tests in `SentryUIViewControllerSwizzlingTests.swift`
  break under Option 1; instantiation-based tests should pass via the funnel (verify, don't assume).
- **Acceptance gate unchanged:** `SubClassFinderRegressionUITests` on the iOS 16.4 sim (crashes
  before the fix, must pass after).

### Risks

- GH-1355 root cause was never pinned; the async design removes every documented trigger, but
  validate the GH-1355 repro shape (Swift convenience-init storyboard VC) on an iOS 15/16 sim before
  merge.
- Third-party init swizzlers (RxSwift, Firebase) stacking on the same base selectors — composes the
  same way as pre-2021; not exhaustively testable.
- CI availability of the iOS 16.4 runtime for the acceptance UITest.

## Before marking ready

- Add `#skip-changelog` to the PR description (last commit is `docs:`; no changelog entry).
- Re-run **tvOS + watchOS** builds on CI (couldn't run locally — no simulator runtimes here).
- Decide whether to keep the `SubClassFinderRegression*` sample fixtures (they intentionally reproduce
  the Finding 4 crash — keep as the acceptance gate for the follow-up, or gate them off).
- Confirm Danger passes; nudge itaybre to resolve the arm64e ptrauth threads (answered +
  device-validated on iPhone 12).
- Flip draft → ready and add `ready-to-merge` for full CI.

## Environment pitfalls (this machine)

- Sim override: `IOS_DEVICE_NAME="iPhone 17 Pro" IOS_SIMULATOR_OS=26.4`; iOS 16.4 sim exists for the
  Finding 4 repro.
- Tests need the `Test` build config (`SENTRY_TEST`): use `make test-ios` (adds `-configuration Test`),
  not a bare `Debug` run. `make build-ios`/`test-ios` honor `FOR_AGENTS=true`.
