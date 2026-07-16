# Handoff: Fix `SentrySubClassFinder` availability crash (GH #8152)

> Temporary working note so this task can be picked up in a later session. Not meant to ship.
> Delete before opening the PR (or move relevant parts into the PR description).

## TL;DR

- **Issue:** [#8152](https://github.com/getsentry/sentry-cocoa/issues/8152) (related: [#3798](https://github.com/getsentry/sentry-cocoa/issues/3798), Swift bug [swiftlang/swift#72657](https://github.com/swiftlang/swift/issues/72657)).
- **Crash:** SDK crashes on start (UIViewController performance tracing) because `SentrySubClassFinder` calls `NSClassFromString` on every class in the app image. That **realizes** the class; realizing a Swift class whose metadata references an `@available`-gated newer-framework type forces Swift metadata completion and crashes with `EXC_BAD_ACCESS` in `swift_getSingletonMetadata` on OS versions below the framework's availability. Reproduces only on **real iOS 17.x (and older) devices**, not simulators.
- **Real-world crashers are NOT view controllers:** SwiftUI gesture `Coordinator: NSObject` (conforms under `UIGestureRecognizerRepresentable`, iOS 18+), `RoomPlan`/`ActivityKit` wrappers.
- **Old mitigation:** users manually set `options.swizzleClassNameExcludes` after discovering the crash. Goal of this work: **stop the crash by default**.
- **Fix (simple, pure Swift):** enumerate classes by reading the image's `__objc_classlist` Mach-O section (gives class **pointers**, NOT realized) instead of `objc_copyClassNamesForImage` + `NSClassFromString`. Then use the _existing_ `class_getSuperclass`-based `isClass(_:subClassOf:)` walk (already safe, never realizes). `NSClassFromString` is only called at swizzle time, on the main thread, for confirmed view controllers.
- **Status:** implemented, unit-tested (7/7 pass on iOS 18.6 sim), differential test added, user confirmed sample no longer crashes. **Committed on branch, not pushed to a PR yet.** No draft PR opened.

## Root-cause chain

`SentrySubClassFinder.actOnSubclassesOfViewController(inImage:)` (background queue):

1. old: `objcRuntimeWrapper.copyClassNamesForImage` → class name C-strings (safe, no realization).
2. old: for each name → `NSClassFromString(name)` ← **THE CRASH** (realizes) → `isClass(subclassOf: UIViewController)` walk → keep name if VC.
3. main thread: `NSClassFromString(name)` again → hand `Class` to swizzle block.

Only step 2's `NSClassFromString` was the problem. `class_getSuperclass` (used by `isClass`) was always safe.

## The fix (what changed)

New approach = same structure, but get class **pointers** without realizing:

- Added `classes(forImage:) -> [AnyClass]` to `SentryObjCRuntimeWrapper` protocol.
- Default impl (`SentryDefaultObjCRuntimeWrapper`): `import MachO`; find the image via `_dyld_image_count`/`_dyld_get_image_name`; read `getsectiondata(header, "__DATA_CONST", "__objc_classlist", &size)` (fallback `"__DATA"`); `unsafeBitCast` each entry to `AnyClass`. These are dyld-bound but **not realized**.
- Finder: iterate `classes(forImage:)`, run the unchanged `isClass` superclass walk, read the name of matches via `class_getName` (does NOT realize, does NOT call `+initialize`), apply `swizzleClassNameExcludes`, collect names. Main-thread pass unchanged (`NSClassFromString` only on confirmed VCs).
- `swizzleClassNameExcludes` kept + doc-reframed as a _fallback_ for the rare residual case (a real VC subclass that itself crashes when realized at swizzle time — unavoidable since swizzling requires realization).

### Files changed (10)

- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift` — swap enumeration; net simpler.
- `Sources/Swift/Helper/SentryObjCRuntimeWrapper.swift` — add `classes(forImage:)` to protocol.
- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift` — implement it (`import MachO`).
- `Sources/Swift/Options.swift` + `Sources/SentryObjC/Public/SentryObjCOptions.h` — reframe `swizzleClassNameExcludes` doc as fallback.
- `CHANGELOG.md` — `## Unreleased` → `### Fixes` entry (#8152).
- `Tests/SentryTests/Integrations/Performance/SentrySubClassFinderTests.swift` — reworked to new seam + new differential test.
- `Tests/SentryTests/Helper/SentryTestObjCRuntimeWrapper.{h,m}` — added `classes` override block (parallels existing `classesNames`).
- `Samples/iOS-Swift/App/Sources/AppDelegate.swift` — **user's own** RoomPlan repro scaffolding; leave as-is (don't touch).

## Why it's safe (verified, not assumed)

Verified against **objc4 source** (`apple-oss-distributions/objc4` main) + empirical tests on Apple M5 Max (arm64):

1. `class_getSuperclass` = `cls->getSuperclass()` — pure field read, **never realizes**, handles arm64e ptrauth internally (`objc-class.mm:802`). The only realizing/crashing call was `NSClassFromString`.
2. `objc_copyClassNamesForImage` returns `demangledName(false)`; `class_getName` returns the same demangled form. Neither realizes. So new names == old names by construction.
3. `class_getName` and the superclass walk do **not** trigger `+initialize`. A Swift `[AnyClass]` append does not either (holds metatype, no retain-message) — unlike ObjC `NSArray addObject:` which does. Tested empirically.
4. **Classes with a Swift-generic superclass** (e.g. `UIHostingController<V>` subclass like the repro's `TestHorizontalGestureVC`) are **not in `__objc_classlist` at all** — AND `objc_copyClassNamesForImage` doesn't return them either (same section), even after instantiation. So switching enumeration loses **zero** coverage; those VCs were never image-enumerated (they're handled by the root-VC swizzle path). This is the key finding that made the complex approach unnecessary.
5. arm64e: no hand-rolled pointer stripping in the fix (we call `class_getSuperclass`, which authenticates correctly). App images are almost always plain arm64 anyway.

### Differential/oracle evidence (ran locally, throwaway scripts in /tmp)

- Enumeration equivalence: across **163 loaded images / 9,610 classes**, new (`__objc_classlist` + `class_getName`) == old (`objc_copyClassNamesForImage`) name set. **0 mismatches.**
- Superclass-walk safety: walked all 9,610 classes with `class_getSuperclass` — no crash, no hang, max chain depth 7, 0 runaway/cyclic chains.

## Rejected over-engineered approach (do NOT resurrect unless needed)

First attempt added a new C file `SentryViewControllerClassScanner.c` doing raw `vm_read`/`sentrycrashmem_copySafely` reads of `class_t.superclass`, `ptrauth_strip`, name-demangle matching, plus a `_SentryPrivate.h` import. Problems: hit the `scripts/check-sentrycrash-imports.sh` ratchet (86/86, "never increase"), and it was all unnecessary once we confirmed `class_getSuperclass` is realization-free. The SentryCrash module (`Sources/SentryCrash/Recording/Tools/SentryCrashObjC.c` etc.) does have battle-tested non-realizing class introspection if ever needed, but note its name-read path assumes a _realized_ class and its `isMemoryReadable` uses a non-thread-safe shared static buffer.

## Tests

- `SentrySubClassFinderTests.swift` reworked: fixture injects `[AnyClass]` via the new `classes` seam (replaced the `classesNames` string seam). Existing behavioral tests preserved (find VCs, honor excludes, ignore non-VC, wrong image, no `+initialize`).
- **New:** `testClassListEnumerationMatchesCopyClassNamesForImage` — iterates every loaded image, asserts new enumeration == `objc_copyClassNamesForImage` name set. Never calls `NSClassFromString` (safe on every OS). Permanent CI guard for the one thing that changed.
- Repro test `testActOnSubclassesOfViewController_WithAvailabilityGatedGestureClass` — real runtime, gated gesture `Coordinator` in binary, asserts no crash + a plain VC is found.
- Requires `@_spi(Private) @testable import Sentry` (the default wrapper is `@_spi(Private)`).

### Verified passing

`make test-ios FOR_AGENTS=true IOS_DEVICE_NAME="iPhone 16" IOS_SIMULATOR_OS=18.6 ONLY_TESTING=SentryTests/SentrySubClassFinderTests`
→ "Executed 7 tests, with 0 failures". The 2 key tests also confirmed by name (2/2 pass).

## Environment / invocation pitfalls (bit me; save time later)

- **Local branch was 7 commits behind `origin/main`**, which independently broke `SentryTestUtils/ClearTestState.swift` (`SentryAppStartMeasurementProvider.reset()` gated behind `#if SENTRY_TEST` didn't exist yet). **Merged `origin/main` into the branch** (local merge commit `25319bf65`, then this work) to fix. This is why the test target wouldn't compile at first.
- Test target only compiles under the **`Test` build configuration** (defines `SENTRY_TEST`). Running via XcodeBuildMCP `test_sim` with default `Debug` FAILS with "no member 'reset'". Use `make test-ios` (sets `-configuration Test`).
- Makefile hardcodes `--os 18.4 --device "iPhone 16 Pro"`; this machine only has iOS **18.6 / iPhone 16**. Override: `IOS_DEVICE_NAME="iPhone 16" IOS_SIMULATOR_OS=18.6`.
- `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` and `GCC_TREAT_WARNINGS_AS_ERRORS=YES`. E.g. `let x = NSClassFromString(...)` needs explicit `: AnyClass` or the build fails on the inference warning.
- SwiftPM `swift build --product Sentry` compiles the SDK but fails at `verify-emitted-module-interface` (unrelated `SentryHeaders` module-interface quirk on macOS standalone). Add `-Xswiftc -no-verify-emitted-module-interface` for a clean SDK compile check.
- `make build-ios`/`make test-ios` also honor `FOR_AGENTS=true` for reduced output; full logs land in `raw-*-output.log` (gitignored).

## Remaining gaps / next steps

1. **Real-device confirmation** on iOS 16/17 with the repro (gated non-VC like RoomPlan wrapper + gesture Coordinator) — user confirmed sample doesn't crash on their run; more devices/OSes + an arm64e-built app would fully close it. (Repro is device-only; CI sims can't reproduce.)
2. **Run the broader swizzling/perf tests** (`SentryUIViewControllerSwizzlingTests`) to be thorough — not yet run this session.
3. `make format` + `make analyze` full pass before PR (swiftlint + clang-format already pass on touched files).
4. **When opening the PR:** delete this handoff file; move summary into the PR body; check `git log main..HEAD` for a claudescope `Agent transcript:` line to include (per AGENTS.md). `feat`/`fix` needs a changelog entry (have it). One maintainer approval; `ready-to-merge` label for full CI.
5. Consider the other verification options not yet done: a written device-test checklist, and/or a safety fallback (if classlist read returns empty, fall back to old behavior for that image) as defense-in-depth.

## Memory

Persistent notes saved in this session's memory:

- `subclassfinder-availability-crash-fix` (the fix + all findings)
- `sentrycrash-raw-objc-introspection` (the rejected-approach primitives, for reference)
