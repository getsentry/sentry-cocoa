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
- **Tests:** `SentrySubClassFinderTests` green on the local sim (9 tests) after the
  merge. Includes the differential enumeration test, the section null-entry test, and
  the real-wrapper regression test.

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
  enumeration; net simpler.
- `Sources/Swift/Core/Integrations/Performance/SentryUIViewControllerSwizzling.swift`
  — comment note that `objc_getClassList` realizes every class.
- `Sources/Swift/Helper/SentryObjCRuntimeWrapper.swift` — add `classes(forImage:)`
  to protocol (+ threading/arch doc).
- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift` — implement it
  (`import MachO`), arch guard, `MH_MAGIC_64` guard, off-main-thread doc. Section
  parsing extracted to a testable `static func classes(inSection:size:)` that reads
  entries as `AnyClass?` and `compactMap`s out nulls (no `unsafeBitCast`).
- `CHANGELOG.md` — `## Unreleased` → `### Fixes` entry (#8457).
- `Tests/.../SentrySubClassFinderTests.swift` — new `classes` seam; differential test
  (`testClassesForImage_whenReadingEveryLoadedImage_shouldMatchCopyClassNamesForImage`),
  section null-entry test (`testClassesInSection_whenSectionContainsNullEntry_shouldSkipIt`),
  real-wrapper regression test
  (`testRealRuntimeWrapper_whenReadingBundleImage_findsBundleViewControllers`) + gated
  `AvailabilityGatedNonViewController` fixture, and the merged-in
  `_NoViewController_DoesNotDispatchToMainQueue` test.
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

## Tests (9 total, all green)

- Behavioral tests inject `[AnyClass]` via the `classes` seam (find VCs, honor
  excludes, ignore non-VC, wrong image, no `+initialize`, and — from the merged
  `#8494` — no main-queue dispatch when there's nothing to swizzle).
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

## Deferred / future work (NOT blocking this PR)

- **Reuse `SentryBinaryImageCache` instead of scanning all dyld images.**
  `classes(forImage:)` currently loops `_dyld_image_count()` to find the header.
  `SentryBinaryImageInfo.address` IS the in-memory `mach_header` pointer
  (`SentryCrashDynamicLinker.c:414` `buffer->address = (uintptr_t)header`), so we
  could pass that straight to `getsectiondata` and skip the loop. **Caveats to
  resolve first:** (1) the cache is populated **async on a background thread** in prod
  (`dispatch_async` in `sentrycrashbic_startCache`), so it may be empty/incomplete
  when the finder runs at startup — needs a fallback to the dyld scan; (2) it's
  indexed **by address, not name** — no by-name lookup exists, would need a linear
  scan of `getAllBinaryImages()` or a new accessor. Decide if the win is worth the
  coupling. (User may tackle this later.)
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

- `make format` + `make analyze` clean; `SentrySubClassFinderTests` green.
- `classes(forImage:)` is `@_spi(Private)` → not in `sdk_api.json` (confirmed absent);
  no `make generate-public-api` needed.
- Confirm Danger passes (changelog references **#8457**, the PR number).
- Then flip draft → ready and add `ready-to-merge` for full CI.
