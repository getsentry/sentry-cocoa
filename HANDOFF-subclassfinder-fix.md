# Handoff: Fix `SentrySubClassFinder` availability crash (GH #8152)

> Working note for picking this up across sessions. Tracks the live PR, decisions,
> and the one deferred optimization. Not part of the shipped SDK.

## Status

- **PR:** [#8457](https://github.com/getsentry/sentry-cocoa/pull/8457), branch
  `fix/subclassfinder-availability-crash`. Open as a **draft** (intentionally — not
  yet marked ready-to-merge; double-checking first).
- **Reviews:** three rounds (philipphofmann, NinjaLikesCheez, itaybre). All raised
  comments addressed in code + replies; see "Review feedback" below.
- **`origin/main` merged in** (merge commit, includes `#8494` "reduce SDK-start
  overhead"). Conflicts in `SentrySubClassFinder.swift` (kept our `[AnyClass]` flow +
  main's empty-check early return; dropped main's `free(classes)`, which was for the
  old C-array API) and its test (kept our `classes` seam + main's
  `_NoViewController_DoesNotDispatchToMainQueue` test adapted to that seam).
- **Tests:** `SentrySubClassFinderTests` green on the local sim (**10 executed**, 0 failures).
  Includes the differential enumeration test, the section null-entry test, the real-wrapper
  regression test, and the filter-drop test noted under Open blockers. The Finding 3 fix adds no
  test — a required-method conformer that omits the method can't compile, so there's no runtime
  path to exercise.
- **Finding 3 (P2, SPI conformer compat): addressed this session (2026-07-23)** via compiler
  directives (method kept required, gates made consistent). Not committed yet. Note the scope: it
  hardens the compile-time contract but does not add a runtime guard for a foreign old-SDK
  conformer. See "Addressed this session" below.
- **Findings 1 & 2 still open**, from [`REVIEW-PR-8457.md`](REVIEW-PR-8457.md), both validated
  and deferred by user (no fix): **Finding 1 (P0)** concurrent image-unload crash and
  **Finding 2 (P1)** unremapped classlist entries. User (2026-07-23) may tackle them later; the
  in-code comments were reframed from "must be resolved before merge" to plain "known
  limitation" notes (they still point here for the full writeup). See "Open blockers" below.
- **These docs are kept as living tracking notes** (user decision 2026-07-23), not deleted
  before merge as the earlier draft of this file assumed.

## Addressed this session (2026-07-23) — Finding 3: SPI conformer compat

Finding 3's stated hazard: `classes(forImage:)` is a **required** member of the
`@objc @_spi(Private)` protocol `SentryObjCRuntimeWrapper`, called unconditionally. An
Objective-C conformer built against an _older_ SDK (ObjC only _warns_ on incomplete conformance)
and injected via the `@objc public var objcRuntimeWrapper` setter would hit
`doesNotRecognizeSelector:` at runtime on the default-on swizzling path. Details:
`REVIEW-PR-8457.md` §"Finding 3".

**User decision (2026-07-23): keep the method _required_, fix with compiler directives, NOT
`@objc optional`.** Changes (not committed yet):

- `Sources/Swift/Helper/SentryObjCRuntimeWrapper.swift` — method stays **required** under the
  existing `#if (os(iOS)||os(tvOS)||os(visionOS)) && (arch(arm64)||arch(x86_64))`; doc note now
  explains the `#if`-not-`optional` rationale.
- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift` — its file-level `#if`
  gained `&& (arch(arm64)||arch(x86_64))` to match the method's gate; call site is a plain direct
  call. On iOS/tvOS/visionOS the arch condition is always true, so no slice that used to build is
  dropped.
- `Sources/Swift/Core/Integrations/Performance/SentryUIViewControllerSwizzling.swift` — holds a
  `SentrySubClassFinder` property, so its file-level `#if` got the same `&& (arch(arm64)||
  arch(x86_64))`. The cascade **stops here**: `SentryDependencyContainer` and
  `SentryPerformanceTrackingIntegration` reference these types inside regions already gated
  `(os(iOS)||os(tvOS)||os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK`, which implies the arch condition
  on those platforms — no change needed there (confirmed by the builds).
- Tests: **no new test** — a required-method conformer that omits it wouldn't compile, so there's
  no in-tree runtime path to exercise.
- API stability: `make generate-public-api` produced **no diff** (SPI excluded from
  `sdk_api*.json`). No `SentryObjC`/`SentryObjCCompat` wrapper change needed.

**What this actually achieves (be precise):** it makes the caller's and swizzler's `#if` gates
consistent with the method's gate (they existed on divergent conditions before — the method was
64-bit-only, the caller wasn't), and keeps the method a hard **compile-time** requirement. Any
conformer compiled _against this SDK version_ (default wrapper, test wrapper, a hybrid SDK building
on current sources) must implement it or fail to build.

**What it does NOT do:** it does not add a runtime guard for a _foreign_ ObjC conformer compiled
against an _older_ SDK and injected at runtime — that object never sees our `#if`, so the direct
call would still `doesNotRecognizeSelector:`. Only `@objc optional` + a `responds(to:)`/skip guard
would close that, which the user chose against. Accepted because it's SPI and the review's
org-wide search found no external conformers. If that vector ever matters, revisit.

Verification: `make format` + `make analyze` clean; builds green on **iOS, macOS, visionOS** (macOS
proves the protocol still compiles where the method is `#if`'d out); `SentrySubClassFinderTests`
10/10 green. tvOS/watchOS builds could not run in this environment — the `Sentry` scheme exposes
only iOS + visionOS simulator destinations here (no tvOS/watchOS Simulator; same pre-existing
environment gap the review hit). tvOS mirrors the iOS/visionOS `#if` shape and watchOS mirrors
macOS, both already exercised. Re-run tvOS/watchOS on CI or a machine with those runtimes.

## Open blockers (deferred — Findings 1 & 2)

> User (2026-07-23): may tackle these later. Kept as tracked known-limitations in code + here.

- **Finding 1 — concurrent image-unload crash (OPEN, P0).** Full writeup + fix plan in
  the "Finding 1" section below (source: `REVIEW-PR-8457.md` §"Finding 1"). `classes(forImage:)`
  can dereference a dangling Mach-O header/section if the target image is unloaded
  mid-read (reviewer reproduced a SIGSEGV). Real but **not reachable in the default
  config** (only the never-unloadable main executable is enumerated by default);
  reachable only for dynamically-unloadable images. Chosen fix direction: coordinate the
  read with the loader via `SentryBinaryImageCache`. Deferred by user (2026-07-21).

- **Finding 2 — raw `__objc_classlist` entries are unremapped (OPEN, P1).** Full
  writeup + follow-up in `REVIEW-PR-8457.md` §"Finding 2". `classes(inSection:size:)`
  returns the raw compiler-emitted pointers without objc4's `remapClass`, and
  `SentrySubClassFinder` carries them across the queue hop straight to the swizzler.
  For a class objc4 remaps, the raw pointer differs from the live class object, which
  can bypass `SentrySwizzle`'s class-identity dedup (`NSMutableSet<Class>` in
  `SentrySwizzle.m`).
  - **An earlier local attempt did NOT fix it** (comment + a filter-drop test only). The
    review disproved the comment's core claim: objc4 only forbids a future class from
    being _completed by a Swift class_, NOT from having an Objective-C view-controller
    superclass. A reserved ObjC `objc_getFutureClass` VC subclass passes
    `SentrySubClassFinder`'s `class_getSuperclass` filter yet has raw ≠ live identity —
    demonstrated by a local probe (`SentryFutureViewController : NSViewController`,
    `rawIsViewController=yes rawEqualsLive=no`).
  - **Local changes currently in the tree (uncommitted):** softened comment in
    `SentryDefaultObjCRuntimeWrapper.swift` (now flags this as a known open issue, no
    longer claims safety) + `testActOnSubclassesOfViewController_WhenClassDoesNotReach`
    `ViewController_IsNotSwizzled` (documents the filter drop for the
    weak-missing-superclass shape only; explicitly NOT a Finding-2 fix).
  - **Constraint on any real fix:** must NOT reintroduce the GH-8152 realization crash.
    The review's "store names, resolve on main via `NSClassFromString`" suggestion
    realizes the class and can pick a same-named class from another image — the exact
    behavior this PR removed. A viable fix likely applies a `remapClass`-equivalent to
    each entry (skipping nil results) transiently while keeping the non-realizing path.
  - **Test gap:** name-set equivalence and the current filter test are insufficient; a
    real regression test needs an ObjC bundle + `objc_getFutureClass` to exercise
    remapping and pointer identity.
  - Deferred by user decision (2026-07-21): store findings now, pick up the fix later.

## TL;DR

- **Issue:** [#8152](https://github.com/getsentry/sentry-cocoa/issues/8152) (related:
  [#3798](https://github.com/getsentry/sentry-cocoa/issues/3798), Swift bug
  [swiftlang/swift#72657](https://github.com/swiftlang/swift/issues/72657)).
- **Crash:** SDK crashes on start (UIViewController performance tracing) because
  `SentrySubClassFinder` called `NSClassFromString` on every class in the app image.
  That **realizes** the class; realizing a Swift class whose metadata references an
  `@available`-gated newer-framework type forces Swift metadata completion and
  crashes with `EXC_BAD_ACCESS` in `swift_getSingletonMetadata` on OS versions below
  the framework's availability. Reproduces only on **real iOS 17.x (and older)
  devices**, not simulators.
- **Real-world crashers are NOT view controllers:** SwiftUI gesture
  `Coordinator: NSObject` (conforms under `UIGestureRecognizerRepresentable`, iOS
  18+), `RoomPlan`/`ActivityKit` wrappers.
- **Fix (pure Swift):** enumerate classes by reading the image's `__objc_classlist`
  Mach-O section (gives class **pointers**, NOT realized) instead of
  `objc_copyClassNamesForImage` + `NSClassFromString`. Then use the existing
  `class_getSuperclass`-based `isClass(_:subClassOf:)` walk (already safe, never
  realizes). The confirmed VC class pointers are carried to the main thread and handed
  straight to the swizzle block — `NSClassFromString` is not used at all anymore (it
  realizes, and could resolve a same-named class from a different image).

## Root-cause chain

`SentrySubClassFinder.actOnSubclassesOfViewController(inImage:)` (background queue):

1. old: `objcRuntimeWrapper.copyClassNamesForImage` → class name C-strings (safe).
2. old: for each name → `NSClassFromString(name)` ← **THE CRASH** (realizes) →
   `isClass(subclassOf: UIViewController)` walk → keep name if VC.
3. old: main thread → `NSClassFromString(name)` again → hand `Class` to swizzle block.

Only step 2's `NSClassFromString` was the problem. `class_getSuperclass` (used by
`isClass`) was always safe. The new code drops `NSClassFromString` entirely (both
steps 2 and 3) — it walks unrealized class pointers and passes them straight to the
swizzle.

## The fix (what changed)

Same structure, but get class **pointers** without realizing:

- Added `classes(forImage:) -> [AnyClass]` to `SentryObjCRuntimeWrapper` protocol.
- Default impl (`SentryDefaultObjCRuntimeWrapper`): `import MachO`; find the image
  via `_dyld_image_count`/`_dyld_get_image_name`; read
  `getsectiondata(header, "__DATA_CONST", "__objc_classlist", &size)` (fallback
  `"__DATA"`); rebind the section to `AnyClass?` (the honest type of its
  `Class _Nullable` entries — no `unsafeBitCast`) and `compactMap` out nulls. These
  are dyld-bound but **not realized**.
- Finder: iterate `classes(forImage:)`, run the unchanged `isClass` superclass walk,
  read names via `class_getName` only to apply `swizzleClassNameExcludes` (neither
  `class_getSuperclass` nor `class_getName` sends a message, so `+initialize` never
  runs on the background thread), then collect the class **pointers** and hand them
  directly to the main-thread swizzle block. Holding/iterating `AnyClass` does not
  message the class either; the swizzle is the first message, and it runs on main.

### Files changed (PR #8457, vs origin/main)

- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift` — swap
  enumeration; net simpler. **Finding 3:** file-level `#if` gained `&& (arch(arm64)||
  arch(x86_64))` to match the required protocol method's gate; plain direct call to
  `classes(forImage:)`.
- `Sources/Swift/Core/Integrations/Performance/SentryUIViewControllerSwizzling.swift`
  — comment note that `objc_getClassList` realizes every class. **Finding 3:** same
  `&& (arch(arm64)||arch(x86_64))` added to its file-level `#if` (it holds a
  `SentrySubClassFinder`).
- `Sources/Swift/Helper/SentryObjCRuntimeWrapper.swift` — add `classes(forImage:)`
  to protocol (+ threading/arch doc). **Finding 3:** kept **required** (not `optional`);
  doc note explains the `#if`-not-`optional` rationale.
- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift` — implement it
  (`import MachO`), arch guard, `MH_MAGIC_64` guard, off-main-thread doc. Section
  parsing extracted to a testable `static func classes(inSection:size:)` that reads
  entries as `AnyClass?` and `compactMap`s out nulls (no `unsafeBitCast`). Finding 1 & 2
  comments reframed to "known limitation" (still point to REVIEW-PR-8457.md / this handoff).
- `CHANGELOG.md` — `## Unreleased` → `### Fixes` entry (#8457).
- `Tests/.../SentrySubClassFinderTests.swift` — new `classes` seam; differential test
  (`testClassesForImage_whenReadingEveryLoadedImage_shouldMatchCopyClassNamesForImage`),
  section null-entry test (`testClassesInSection_whenSectionContainsNullEntry_shouldSkipIt`),
  real-wrapper regression test
  (`testRealRuntimeWrapper_whenReadingBundleImage_findsBundleViewControllers`) + gated
  `AvailabilityGatedNonViewController` fixture, and the merged-in
  `_NoViewController_DoesNotDispatchToMainQueue` test. (Finding 3 adds no test — see above.)
- `Tests/SentryTests/Helper/SentryTestObjCRuntimeWrapper.{h,m}` — added `classes`
  override block (parallels existing `classesNames`).

Note: `Sources/Swift/Options.swift` and `Sources/SentryObjC/Public/SentryObjCOptions.h`
are NOT changed for docs — an earlier draft added a `swizzleClassNameExcludes`
"fallback" paragraph that was removed per review; the option's doc is unchanged from
`main`.

## Review feedback (all addressed)

- **arch guard** (NinjaLikesCheez, `m`): gate the `#if` to 64-bit archs since we bind
  to `mach_header_64`. Done: `(arch(arm64) || arch(x86_64))`. Used `x86_64` (not
  `arm64e`) because Swift's `arch(arm64)` already matches `arm64e`, and `x86_64` is
  needed for the Intel simulator. Commit `62b002c8d`.
- **magic check** (itaybre `l` → NinjaLikesCheez upgraded to `h`, tied to the FAT
  thread): verify `header.pointee.magic == MH_MAGIC_64` before rebinding. Done. Also
  answers FAT: a FAT container has `FAT_MAGIC`, fails the check, so we skip rather
  than misread. No FAT parsing added — `_dyld_get_image_header` only returns thin,
  in-memory, native-arch slices, so a FAT header can't reach this code. Mirrors the
  repo's only precedent, `firstCmdAfterHeader` in `SentryCrashDynamicLinker.c`.
- **arm64e ptrauth** (itaybre, `m`): **RESOLVED — device-validated safe.** Built the
  iOS-Swift sample `ARCHS=arm64e ONLY_ACTIVE_ARCH=NO` and ran on a physical iPhone 12
  (A14, iOS 26.5); app + `iOS-Swift.debug.dylib` + `Sentry.framework` all arm64e. The
  SDK read 44 classrefs from the arm64e `__objc_classlist`, walked superclasses, and
  swizzled 31 UIViewController subclasses with zero `EXC_BAD_ACCESS`. dyld applies
  chained fixups **in place** at load time, so the in-memory section already holds
  runtime-correct pointers that `class_getSuperclass`/`class_getName` accept directly —
  no ptrauth strip needed. (Static/on-disk parsers would still need to decode fixups.)
- **`unsafeBitcast` to `mach_header_64` to save the rebind** (NinjaLikesCheez, `l`):
  kept `withMemoryRebound` for clarity.
- **dyld lock (new, self-found):** verified against Apple dyld source
  (`DyldAPIs.cpp`): `_dyld_image_count()` does NOT lock, but
  `_dyld_get_image_header`/`_dyld_get_image_name` acquire the dyld loader **read
  lock** (`withLoadersReadLock`). So `classes(forImage:)` must run off the main
  thread. Added doc comments on both the impl and the protocol. No behavior change:
  the sole caller already runs it on a background queue via `dispatchAsync`.

## Why it's safe (verified, not assumed)

Verified against **objc4 source** + empirical tests on Apple silicon (arm64):

1. `class_getSuperclass` = `cls->getSuperclass()` — pure field read, **never
   realizes**, handles arm64e ptrauth internally. The only realizing/crashing call
   was `NSClassFromString`.
2. `objc_copyClassNamesForImage` returns `demangledName(false)`; `class_getName`
   returns the same demangled form. Neither realizes. So new names == old names by
   construction.
3. `class_getName` and the superclass walk do **not** trigger `+initialize` —
   `+initialize` fires only on the first _message send_, and neither function messages
   the class. Holding/iterating an `AnyClass` in a Swift array doesn't message it
   either (metatype pointer, no retain-message) — unlike ObjC `NSArray addObject:`.
   Guarded by `testGettingSubclasses_DoesNotCallInitializer` (registers a class with a
   custom `+initialize`, asserts the finder never calls it). This is why passing the
   class pointer to the main thread (instead of a name) is safe: the swizzle block is
   the first message and it runs on main.
4. **Classes with a Swift-generic superclass** (e.g. a `UIHostingController<V>`
   subclass) are **not in `__objc_classlist`** — and `objc_copyClassNamesForImage`
   doesn't return them either (same section). So switching enumeration loses **zero**
   coverage; those VCs were never image-enumerated (handled by the root-VC swizzle
   path). Key finding that made a more complex approach unnecessary.
5. arm64e: no hand-rolled pointer stripping (we call `class_getSuperclass`, which
   authenticates correctly). App images are almost always plain arm64 anyway.

### Differential/oracle evidence

- `testClassesForImage_whenReadingEveryLoadedImage_shouldMatchCopyClassNamesForImage`
  iterates every loaded image and asserts the new (`__objc_classlist` + `class_getName`)
  name set equals the old (`objc_copyClassNamesForImage`) set. Never calls
  `NSClassFromString`, so it's safe on every OS. Permanent CI guard for the one thing
  that changed.
- Local throwaway oracle (earlier session): across ~163 images / ~9,610 classes, new
  == old, 0 mismatches; superclass walk over all classes: no crash, max depth 7, 0
  cycles.

## Tests (10 executed, all green)

> 11 `func test` methods, but `testActOnSubclassesOfViewController()` is shadowed by an
> xcodebuild prefix-collision quirk under class-level `--only-testing` (its name is a
> prefix of the other `testActOnSubclassesOfViewController_*` methods), so the run
> reports 10. It still runs in the full-target CI run.

- Behavioral tests inject `[AnyClass]` via the `classes` seam (find VCs, honor
  excludes, ignore non-VC, wrong image, no `+initialize`, and — from the merged
  `#8494` — no main-queue dispatch when there's nothing to swizzle).
- `testActOnSubclassesOfViewController_WhenClassDoesNotReachViewController_IsNotSwizzled`
  — documents the superclass-walk filter drop (Finding 2 partial guard; NOT a Finding-2
  fix — see Open blockers).
- `testClassesForImage_whenReadingEveryLoadedImage_shouldMatchCopyClassNamesForImage`
  — differential enumeration equivalence (above).
- `testClassesInSection_whenSectionContainsNullEntry_shouldSkipIt` — hands the
  `classes(inSection:size:)` helper a crafted buffer with a null slot and asserts the
  null is skipped.
- `testRealRuntimeWrapper_whenReadingBundleImage_findsBundleViewControllers` — drives
  the **real** `SentryDefaultObjCRuntimeWrapper` through the finder against this
  bundle; asserts the bundle's VCs are found and non-VCs (incl. the gated
  `AvailabilityGatedNonViewController`) are not. The actual `EXC_BAD_ACCESS` is
  device/OS-version-specific and can't be reproduced on CI sims, so this guards the
  enumeration + selection behavior, not the crash itself.
- Requires `@_spi(Private) @testable import Sentry` (the default wrapper is
  `@_spi(Private)`).

## Finding 1 (P0) — concurrent image-unload crash: full writeup + fix plan

> Source report: [`REVIEW-PR-8457.md`](REVIEW-PR-8457.md) "Finding 1: Concurrent
> Image Unload Can Crash". Validated this session; **no code committed**. Pick up here.
> Summarized under "Open blockers" above.

### Verdict: the finding is ACCURATE (real crash), reachable only in non-default configs.

`classes(forImage:)` (`Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift:28-70`)
matches an image by name (`:33`), gets its header (`:36`), then dereferences it via
`getsectiondata` (`:56-59`). Between the match and the deref, another thread can
`dlclose`/unload that image, leaving a **dangling header/section → SIGSEGV**. The
reviewer reproduced this (probe exit 139). Violates "never crash the host app".

**My existing in-file comment is WRONG and must be corrected as part of the fix.**
`SentryDefaultObjCRuntimeWrapper.swift:29-31` (and the "dyld lock" note above) claim
`_dyld_*` "stale indices just return nil" makes this safe. It does not:

- Apple's `dyld.h` (the exact SDK header) says this iteration is **not thread-safe** —
  "Another thread can add or remove an image during the iteration."
- dyld source (`DyldAPIs.cpp`): `_dyld_get_image_header`/`_dyld_get_image_name` take
  `withLoadersReadLock` **only around the array access**; the lock is released before
  returning, so it does **not** pin the image. `nil` is returned only for
  out-of-bounds indices, not for an in-bounds index whose image was unmapped.

### Reachability (why it's not a fire drill, but still must be fixed)

- **Default is safe:** `inAppIncludes` defaults to just `CFBundleExecutable`
  (`Options.swift:416-423`) → the main executable, which can never be unloaded.
- **Reachable when the enumerated image is dynamically unloadable:** (a) a user adds a
  framework/bundle prefix via the public `add(inAppInclude:)` (`Options.swift:425-429`),
  or (b) the app-delegate / root-VC classes live in a `dlopen`-able framework — that
  path passes `class_getImageName(...)` straight in
  (`SentryUIViewControllerSwizzling.swift:123-142, 251`). The finder runs on a
  background queue (`SentrySubClassFinder.swift:31`), so a concurrent unload is possible.
- Note the old `objc_copyClassNamesForImage` held the objc `runtimeLock` during
  enumeration (safe vs concurrent map/unmap) but its returned name strings point into
  `__TEXT` and also dangle if the image unloads after — so the fix must be safe both
  **during and after** the read.

### Chosen fix direction: coordinate with the loader via the binary-image cache

Decided approach (over the lighter `dlopen(RTLD_NOLOAD)` pin): make the header read
coordinate with dyld load/unload so an unload cannot complete while we read. Reuse
`SentryBinaryImageCache` (unload-aware, lock-protected) rather than the raw
`_dyld_*` scan. (This subsumes the "Reuse SentryBinaryImageCache" deferred item above —
now it's a correctness fix, not just a perf tidy.)

**What the cache gives us today** (`Sources/Swift/Core/Helper/SentryBinaryImageCache.swift`,
C in `Sources/SentryCrash/Recording/SentryCrashBinaryImageCache.c`):

- Registered on dyld add/remove callbacks; `SentryBinaryImageInfo` exposes both `name`
  and the header `address`.
- Swift layer guards with an `NSRecursiveLock`; the C remove-callback runs under dyld's
  loader lock.

**Gaps to close (the actual work):**

1. **No by-name lookup** — cache is address-keyed (`imageByAddress`), no
   name→image accessor. Add one (or a `getAllBinaryImages()` scan) to resolve the
   requested image name → its header address.
2. **No lifetime guarantee during the read** — the cache tells you an image _was_
   loaded; it doesn't keep it mapped while you `getsectiondata`. Need one of:
   - read the section while holding the cache lock so a concurrent removal (which goes
     through the locked remove path) can't complete mid-read, **or**
   - detect-and-abort: re-check the image is still present immediately around the read
     and bail on removal (weaker; narrows but doesn't fully close the window), **or**
   - pin for the read with `dlopen(path, RTLD_NOLOAD)` + `dlclose` (bumps refcount so it
     can't unmap) — decide if this belongs inside the cache-coordinated path.
     Decide which guarantee we actually want (true mutual-exclusion vs detect-and-abort).
3. **Async cache population** — the C cache starts on a background queue at startup
   (`sentrycrashbic_startCache`), so it may be incomplete when the finder runs early.
   Need a fallback (e.g. the current dyld scan, but made unload-safe) or gate on
   readiness. Don't leave a window where the finder silently finds nothing.

**Open design question to resolve first:** does `dlopen(mainExecutablePath, RTLD_NOLOAD)`
return a valid handle? Undocumented for the main-program _path_ (vs `NULL`). If any
pinning is used, verify on device that the **default main-exe path doesn't regress**
(it's the common, currently-working case). Prefer a design that degrades to today's
behavior for non-unloadable images rather than dropping them.

**No repo prior art for pinning** — `RTLD_NOLOAD`/`dlclose` appear nowhere in
`Sources/`. This introduces a new pattern; keep it small and well-commented.

### Test to add (reviewer asks for an unload-race regression test — decision deferred)

No `dlopen`/`MH_BUNDLE` harness exists in the `SentryTests` target. Options, cheapest
first: (a) unit-test the new by-name/lock path against a real already-loaded image
(reuse `SentryTestUtilsDynamic.framework`'s `ExternalUIViewController`, the existing
cross-image fixture); (b) mirror `SentryCrashBinaryImageCacheTests`' callback-replay
style to simulate remove-during-read without real unmapping; (c) full concurrent
`dlopen`/`dlclose` harness (closest to the repro, but new build target + timing-flaky).
Pick when implementing.

### Verification when picked up

- `make build-ios` + `make test-ios ONLY_TESTING=SentryTests/SentrySubClassFinderTests`.
- If pinning is used: on-device check that the **default** (main-exe) path still finds
  and swizzles the app's VCs (reuse the arm64e iPhone 12 setup from the arm64e item).
- Re-run iOS 15.5 + current iOS (report ran both, 10/10).
- Fix the wrong `_dyld_*`-safety comment in `SentryDefaultObjCRuntimeWrapper.swift`.

## Deferred / future work (NOT blocking this PR)

- **Reuse `SentryBinaryImageCache`** — now folded into the Finding 1 (P0) fix above
  (it's a correctness requirement there, no longer just a perf tidy). Caveats to resolve
  are listed under Finding 1's "Gaps to close".
- **On-device arm64e run: DONE** (see arm64e item above — iPhone 12, no crash).
- **Perf** of the section read + superclass walk vs the old path on a real device.

## Rejected over-engineered approach (do NOT resurrect unless needed)

First attempt added a C file doing raw `vm_read`/`sentrycrashmem_copySafely` reads of
`class_t.superclass`, `ptrauth_strip`, name-demangle matching, plus a `_SentryPrivate.h`
import. It hit the `scripts/check-sentrycrash-imports.sh` ratchet and was unnecessary
once we confirmed `class_getSuperclass` is realization-free. The SentryCrash module has
battle-tested non-realizing class introspection if ever needed, but note its name-read
path assumes a _realized_ class and its `isMemoryReadable` uses a non-thread-safe shared
static buffer.

## Environment / invocation pitfalls

- Test target only compiles under the **`Test` build configuration** (defines
  `SENTRY_TEST`). Use `make test-ios` (sets `-configuration Test`), not a bare
  XcodeBuildMCP `test_sim` with `Debug`.
- This machine's sim: override `IOS_DEVICE_NAME="iPhone 17 Pro" IOS_SIMULATOR_OS=26.4`.
- `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` / `GCC_TREAT_WARNINGS_AS_ERRORS=YES`.
- `make build-ios`/`make test-ios` honor `FOR_AGENTS=true`; full logs in
  `raw-*-output.log` (gitignored).

## Before marking ready

- **Decide on Findings 1 & 2** (see "Open blockers"): Finding 1 (P0) and Finding 2 (P1) are
  deferred by user (2026-07-23), reframed as known-limitation code comments — not GitHub issues.
  Confirm the user wants to ship with them open (they're local-review findings, never posted to
  GitHub; the actual GitHub reviewers are positive). Finding 3 (P2) is **addressed** this session
  (compile-time gate consistency; see the scope caveat under "Addressed this session").
- `make format` + `make analyze` clean; `SentrySubClassFinderTests` green (10/10).
- `classes(forImage:)` is `@_spi(Private)` → not in `sdk_api.json` (confirmed absent). After the
  Finding 3 `#if` change, `make generate-public-api` still produced no diff.
- Re-run tvOS + watchOS builds on CI / a machine with those simulator runtimes (couldn't run
  locally — see "Addressed this session").
- Confirm Danger passes (changelog references **#8457**, the PR number).
- Nudge itaybre to resolve the 2 arm64e ptrauth threads (answered + device-validated).
- Then flip draft → ready and add `ready-to-merge` for full CI.
