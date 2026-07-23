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
  regression test, and the filter-drop test noted under Open blockers.
- **Latest work — `SentryImageClassProvider` extraction (committed `3a3abd444`, 2026-07-23).**
  `classes(forImage:)` (+ its `classes(inSection:size:)` helper) was moved OFF `SentryObjCRuntimeWrapper`
  into a dedicated pure-Swift `SentryImageClassProvider` protocol + `SentryDefaultImageClassProvider`
  impl (it reads a Mach-O section via dyld, not the ObjC runtime, so it never belonged there).
  `SentrySubClassFinder` now depends on the new provider. This subsumes the earlier Finding 3
  "compiler-directive" fix — the arch `#if` gates carried over. See "Extraction refactor" below.
- **Finding 3 (P2, SPI conformer compat): resolved.** `classes(forImage:)` is no longer on the
  injectable `SentryObjCRuntimeWrapper` SPI protocol at all, so the "old ObjC conformer missing the
  selector" hazard is gone by construction. The new `SentryImageClassProvider` is internal (not
  `@objc`, not `@_spi` public), so it isn't an injectable SPI surface. Removed from `REVIEW-PR-8457.md`.
- **Finding 1 (P0) — resolved as an accepted, documented limitation.** User decided **allow all
  images, document the risk**: no code change, no `SentryBinaryImageCache` integration, no filetype
  guard, no pinning. The "coordinate the read via the cache" direction was investigated and rejected
  (it protects only the read, not the later `class_getSuperclass`/swizzle use of the returned
  pointers). In-code comment is an accurate known-limitation note (now in
  `SentryDefaultImageClassProvider.swift`). Removed from `REVIEW-PR-8457.md`; full trail kept below.
- **Finding 2 (P1) — OPEN, deferred.** Unremapped raw `__objc_classlist` pointers reach the swizzler.
  Still the only open finding in `REVIEW-PR-8457.md`. See "Open blockers" below.
- **These docs are kept as living tracking notes** (user decision 2026-07-23), not deleted
  before merge.

## Extraction refactor (committed `3a3abd444`, 2026-07-23) — `SentryImageClassProvider`

`classes(forImage:)` reads a Mach-O `__objc_classlist` section via dyld — it does **not** call the
Objective-C runtime — so it didn't belong on `SentryObjCRuntimeWrapper` (whose other two methods,
`copyClassNamesForImage`/`classGetImageName`, genuinely are ObjC-runtime calls). It was extracted
into its own protocol-oriented seam. This also **resolves Finding 3**: the method is off the
injectable SPI protocol entirely, so an old ObjC conformer can no longer be missing its selector.

Files (all committed):

- **New `Sources/Swift/Helper/SentryImageClassProvider.swift`** — pure-Swift `protocol
  SentryImageClassProvider { func classes(forImage:) -> [AnyClass] }`. Internal, **not** `@objc`,
  **not** `NSObject`, **not** `@_spi(Private)` (no ObjC caller; precedent: `SentryInfoPlistWrapperProvider`).
  File-gated `#if (os(iOS)||os(tvOS)||os(visionOS)) && (arch(arm64)||arch(x86_64))`.
- **New `Sources/Swift/Helper/SentryDefaultImageClassProvider.swift`** — `final class
  SentryDefaultImageClassProvider: SentryImageClassProvider`. Holds the moved `classes(forImage:)`
  body verbatim (dyld scan, `MH_MAGIC_64` guard, `getsectiondata`) + the internal static
  `classes(inSection:size:)`. The Finding 1 (image-unload) and Finding 2 (unremapped pointers)
  known-limitation comments now live here.
- `Sources/Swift/Helper/SentryObjCRuntimeWrapper.swift` — `classes(forImage:)` **removed**; protocol
  is back to its two ObjC-runtime methods.
- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift` — impl + static helper removed;
  dropped the now-unused `import MachO`.
- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift` — depends on
  `SentryImageClassProvider` (property/init/call); no longer references `SentryObjCRuntimeWrapper`.
  Keeps its file-level arch `#if` (added in the earlier compiler-directive step, `2aa8fa39e`).
- `Sources/Swift/SentryDependencyContainer.swift` — added a gated `var imageClassProvider:
  SentryImageClassProvider = SentryDefaultImageClassProvider()` next to `objcRuntimeWrapper`, and
  `getUIViewControllerSwizzlingBuilder` passes it to the finder. `SentryUIViewControllerSwizzling`
  still gets `objcRuntimeWrapper` (it uses `classGetImageName`). `Dependencies.swift` untouched.
- Tests — `SentrySubClassFinderTests` now injects a small Swift `TestImageClassProvider` fake
  (replaces the old ObjC `SentryTestObjCRuntimeWrapper.classes` block seam); the 3 real-wrapper tests
  point at `SentryDefaultImageClassProvider`. `SentryUIViewControllerSwizzlingTests`' `TestSubClassFinder`
  init updated. `SentryTestObjCRuntimeWrapper.{h,m}` dropped the now-orphaned `classes` block +
  `classesForImage:` (it's still used by `LoadValidatorTests` for the other two methods).

Verification (2026-07-23): `make format` + `make analyze` clean; builds green on **iOS, macOS,
visionOS** (macOS proves the carve compiles where the new type is gated out); tests green —
`SentrySubClassFinderTests` 10/0, `SentryUIViewControllerSwizzlingTests` 31/0, `LoadValidatorTests`
7/0; `make generate-public-api` **no diff** (all new symbols internal; removed protocol member was
`@_spi`). tvOS/watchOS builds could not run in this environment (the `Sentry` scheme exposes only
iOS + visionOS simulator destinations here) — tvOS mirrors the iOS/visionOS `#if` shape, watchOS
mirrors macOS. Re-run tvOS/watchOS on CI.

### Earlier compiler-directive step (`2aa8fa39e`, superseded by the extraction)

Before the extraction, Finding 3 was addressed by keeping `classes(forImage:)` a **required**
`SentryObjCRuntimeWrapper` member and making the caller/swizzler `#if` gates match its 64-bit gate
(the user rejected `@objc optional`). Those arch gates carried into the extraction. That step
hardened the compile-time contract but didn't remove the injectable-SPI surface; the extraction does.

## Open blockers (Finding 2 open; Finding 1 resolved as accepted risk)

> User (2026-07-23): Finding 1 resolved as a documented limitation (details below); Finding 2 may
> be tackled later. Kept as tracked known-limitations in code + here.

- **Finding 1 — concurrent image-unload crash (RESOLVED: accepted risk, no code change).** Full
  writeup + the empirical investigation that drove this decision are in the "Finding 1" section
  below (source: `REVIEW-PR-8457.md` §"Finding 1"). Summary: `classes(forImage:)` can dereference a
  dangling Mach-O header/section if the target image is unloaded mid-read (reviewer + this session
  both reproduced a SIGSEGV), **and** the returned class pointers can dangle later at
  `class_getSuperclass`/swizzle time. Reachable only for a concurrently-unloaded `MH_BUNDLE`; the
  default (`MH_EXECUTE` main exe) and frameworks/embedded dylibs (`MH_DYLIB`) don't unload. Decided
  **allow all + document** — see the retraction of the cache fix direction below.

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
  - **Committed state:** the known-limitation comment lives in
    `SentryDefaultImageClassProvider.swift` (moved there by the extraction refactor; flags this as a
    known open issue, does not claim safety), plus
    `testActOnSubclassesOfViewController_WhenClassDoesNotReachViewController_IsNotSwizzled` (documents
    the filter drop for the weak-missing-superclass shape only; explicitly NOT a Finding-2 fix).
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

- `classes(forImage:) -> [AnyClass]` lives on the `SentryImageClassProvider` protocol (extracted
  2026-07-23 — see "Extraction refactor"; originally on `SentryObjCRuntimeWrapper`).
- Default impl (`SentryDefaultImageClassProvider`): `import MachO`; find the image
  via `_dyld_image_count`/`_dyld_get_image_name`; read
  `getsectiondata(header, "__DATA_CONST", "__objc_classlist", &size)` (fallback
  `"__DATA"`); rebind the section to `AnyClass?` (the honest type of its
  `Class _Nullable` entries — no `unsafeBitCast`) and `compactMap` out nulls. These
  are dyld-bound but **not realized**.
- Finder: iterate `imageClassProvider.classes(forImage:)`, run the unchanged `isClass` superclass walk,
  read names via `class_getName` only to apply `swizzleClassNameExcludes` (neither
  `class_getSuperclass` nor `class_getName` sends a message, so `+initialize` never
  runs on the background thread), then collect the class **pointers** and hand them
  directly to the main-thread swizzle block. Holding/iterating `AnyClass` does not
  message the class either; the swizzle is the first message, and it runs on main.

### Files changed (PR #8457, vs origin/main) — final state

- **`Sources/Swift/Helper/SentryImageClassProvider.swift`** (new) — pure-Swift protocol holding
  `classes(forImage:)`; file-gated to 64-bit iOS/tvOS/visionOS.
- **`Sources/Swift/Helper/SentryDefaultImageClassProvider.swift`** (new) — default impl: `import
  MachO`, dyld scan, `MH_MAGIC_64` guard, `getsectiondata`, `AnyClass?` rebind + `compactMap`
  (no `unsafeBitCast`), and the internal static `classes(inSection:size:)`. Holds the Finding 1 & 2
  known-limitation comments (point to REVIEW-PR-8457.md / this handoff).
- `Sources/Swift/Helper/SentryObjCRuntimeWrapper.swift` — back to its two ObjC-runtime methods
  (`classes(forImage:)` extracted out).
- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift` — impl + static helper removed;
  dropped the now-unused `import MachO`.
- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift` — enumeration swap (net
  simpler); depends on `SentryImageClassProvider` (not `SentryObjCRuntimeWrapper`); file-level `#if`
  carries the `&& (arch(arm64)||arch(x86_64))` gate.
- `Sources/Swift/Core/Integrations/Performance/SentryUIViewControllerSwizzling.swift` — comment note
  that `objc_getClassList` realizes every class; same `&& (arch(arm64)||arch(x86_64))` on its
  file-level `#if` (it holds a `SentrySubClassFinder`).
- `Sources/Swift/SentryDependencyContainer.swift` — gated `imageClassProvider` var; builder passes it
  to the finder.
- `CHANGELOG.md` — `## Unreleased` → `### Fixes` entry (#8457).
- `Tests/.../SentrySubClassFinderTests.swift` — Swift `TestImageClassProvider` seam; differential test
  (`testClassesForImage_whenReadingEveryLoadedImage_shouldMatchCopyClassNamesForImage`),
  section null-entry test (`testClassesInSection_whenSectionContainsNullEntry_shouldSkipIt`),
  real-wrapper regression test
  (`testRealRuntimeWrapper_whenReadingBundleImage_findsBundleViewControllers`) + gated
  `AvailabilityGatedNonViewController` fixture, and the merged-in
  `_NoViewController_DoesNotDispatchToMainQueue` test.
- `Tests/SentryTests/Integrations/Performance/UIViewController/SentryUIViewControllerSwizzlingTests.swift`
  — `TestSubClassFinder` init takes `imageClassProvider:`.
- `Tests/SentryTests/Helper/SentryTestObjCRuntimeWrapper.{h,m}` — dropped the `classes` block +
  `classesForImage:` (orphaned by the extraction); other two methods retained for `LoadValidatorTests`.

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
  the **real** `SentryDefaultImageClassProvider` through the finder against this
  bundle; asserts the bundle's VCs are found and non-VCs (incl. the gated
  `AvailabilityGatedNonViewController`) are not. The actual `EXC_BAD_ACCESS` is
  device/OS-version-specific and can't be reproduced on CI sims, so this guards the
  enumeration + selection behavior, not the crash itself.
- Requires `@_spi(Private) @testable import Sentry` (the default wrapper is
  `@_spi(Private)`).

## Finding 1 (P0) — concurrent image-unload crash: full writeup + resolution

> Source report: [`REVIEW-PR-8457.md`](REVIEW-PR-8457.md) "Finding 1: Concurrent
> Image Unload Can Crash". Validated across sessions. **Resolution (2026-07-23): accepted as a
> documented limitation — no code change.** Summarized under "Open blockers" above.

### Verdict: the finding is ACCURATE (real crash), but narrow, and NOT fixable at the read.

`classes(forImage:)` (`Sources/Swift/Helper/SentryDefaultImageClassProvider.swift`)
matches an image by name, gets its header, then dereferences it via `getsectiondata`.
Between the match and the deref, another thread can `dlclose`/unload that image, leaving a
**dangling header/section → SIGSEGV**. Reproduced by the reviewer (probe exit 139) and again this
session. The earlier in-file comment claiming `_dyld_*` "stale indices just return nil" was wrong
(`dyld.h` documents the iteration as not thread-safe; `_dyld_get_image_header`/`_dyld_get_image_name`
hold `withLoadersReadLock` only around the array access, not across the deref) — that comment has
been corrected.

### Empirical investigation (2026-07-23) — what actually determines the risk

Reproduced locally on darwin/arm64 with minimal ObjC images:

1. **Only `MH_BUNDLE` unloads.** A `dlopen`-able `.bundle` (built `clang -bundle`) with an ObjC
   class: `dlclose` → class deregistered, image unmapped → `getsectiondata` on the stale header
   **SIGSEGV (exit 139)**. The _same_ ObjC class built as an `MH_DYLIB` (`clang -dynamiclib`) was
   **not** unloaded even after repeated `dlclose` (ObjC/Swift runtime registration pins it —
   matches Apple/Quinn's "runtimes don't support unloading" rule). The default `inAppInclude` is the
   main executable (`MH_EXECUTE`), which never unloads.
2. **`.xctest` binaries are `MH_DYLIB`, not `MH_BUNDLE`** (verified via `otool -hv`), so the test
   images this code reads are in the safe category.
3. **The decisive result: a read-time fix does not prevent the crash.** `classes(inSection:)`
   returns raw class pointers that live in the image's `__DATA`/`__DATA_CONST` — it does not copy
   the classes. Those pointers are used _after_ `classes(forImage:)` returns: `SentrySubClassFinder`
   walks `class_getSuperclass` on a background queue, hops to the main queue, and swizzles.
   Reproduced **SIGSEGV (exit 139)** calling `class_getSuperclass` on a class pointer whose bundle
   had been unloaded. So cache+lock, `RTLD_NOLOAD` pinning, or any read-scoped synchronization
   protects only the microseconds inside the read and leaves the swizzle-time crash open. The
   exposure is inherent to swizzling classes from an image that may unload.

### Reachability

- **Default safe:** `inAppIncludes` defaults to `CFBundleExecutable` → main executable.
- **Frameworks/embedded dylibs safe:** `MH_DYLIB` doesn't unload once it registers ObjC/Swift.
- **Only exposed case:** an app `dlopen`s an ObjC/VC-containing `MH_BUNDLE`, points the SDK at it
  (via `add(inAppInclude:)` or a root VC living in it — `SentryUIViewControllerSwizzling.swift`),
  and `dlclose`s it concurrently while the finder runs on its background queue.

### Resolution: allow all images, document the risk (RETRACTS the cache fix direction)

**User decision (2026-07-23): allow all images and document the limitation. No code change.**
Rationale: (a) a read-time fix cannot close the crash (finding 3 above); (b) refusing `MH_BUNDLE`
would silently drop instrumentation for the legitimate resident-bundle case (a bundle loaded once
and never unloaded is safe); (c) pinning the image would prevent an unload the app may want and is a
larger footprint than a telemetry SDK should take unprompted.

**The previously "chosen" fix — coordinate the read via `SentryBinaryImageCache` — is retracted.**
It was investigated in depth and rejected: it protects only the read (not the later
superclass-walk/swizzle use of the returned pointers), and it carries its own downsides (async cache
population → early-miss window that would silently find no classes; a `MAX_DYLD_IMAGES` cap). It is
therefore not pursued. Likewise `RTLD_NOLOAD`/`RTLD_NODELETE` pinning and a `filetype` allow/deny
guard were considered and declined.

If this ever needs a real fix, the only robust directions are: refuse to instrument unloadable
(`MH_BUNDLE`) images outright, or permanently pin (leak) any image whose classes are swizzled —
both trade instrumentation coverage or memory for safety.

### Test (no longer applicable)

No regression test is added: the resolution is "accept + document," with no code change to guard.
An unload-race test would only exercise a guard we intentionally didn't build. (Had we guarded, note
that `.xctest` binaries are `MH_DYLIB`, so a real `MH_BUNDLE` unload harness would have needed a new
build target anyway.)

### Verification (done)

- The only change is comments/docs. `make format` + `make build-ios` confirm the edited file still
  compiles. `SentrySubClassFinderTests` remain valid unchanged (no behavior change).
- The misleading `_dyld_*`-safety comment (originally in `SentryDefaultObjCRuntimeWrapper.swift`,
  now in `SentryDefaultImageClassProvider.swift`) has been corrected to the accurate
  known-limitation note.

## Deferred / future work (NOT blocking this PR)

- **Reuse `SentryBinaryImageCache`** — investigated and **rejected** (see Finding 1's Resolution
  above). It doesn't fix the crash (protects only the read, not the swizzle-time use of the returned
  pointers) and adds an async-population early-miss window plus a `MAX_DYLD_IMAGES` cap. Not pursued.
  A perf motivation alone doesn't justify it: the `_dyld_*` scan is microseconds and runs ~once.
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

- **Findings:** Finding 3 (P2) is **resolved** by the `SentryImageClassProvider` extraction
  (`classes(forImage:)` is off the injectable SPI protocol entirely). Finding 1 (P0) is **resolved as
  an accepted, documented limitation** — allow all images, no code change; see "Finding 1" Resolution.
  Finding 2 (P1) remains **deferred** by user, kept as a known-limitation code comment. All are
  local-review findings, never posted to GitHub; the actual GitHub reviewers are positive.
- `make format` + `make analyze` clean; the 3 affected test targets green
  (`SentrySubClassFinderTests` 10/0, `SentryUIViewControllerSwizzlingTests` 31/0, `LoadValidatorTests` 7/0).
- New provider symbols are internal, and `classes(forImage:)` left an `@_spi(Private)` protocol →
  `make generate-public-api` produced no diff.
- Re-run tvOS + watchOS builds on CI / a machine with those simulator runtimes (couldn't run
  locally — see "Extraction refactor").
- Confirm Danger passes (changelog references **#8457**, the PR number).
- Nudge itaybre to resolve the 2 arm64e ptrauth threads (answered + device-validated).
- Then flip draft → ready and add `ready-to-merge` for full CI.
