# PR 8457 Local Review Handoff

## Review Status

- PR: `https://github.com/getsentry/sentry-cocoa/pull/8457`
- Title: `fix: prevent SubClassFinder availability crash`
- Reviewed head: `6e8284f8718f1fc665bafbb10ea545c8f08c7ec3`
- Base during review: `main` at `6d9248043b5919d9b675d9e743188924b44b6bf6`
- Review date: July 21, 2026
- Original verdict: **Do not merge yet** (Findings 1 P0, 2 P1, 3 P2)
- Status update (2026-07-23): **Finding 1 and Finding 3 resolved** and removed from this document
  (Finding 1 — accepted, documented image-unload limitation, no code change; Finding 3 — SPI
  conformer compat, fixed via compiler directives + the `SentryImageClassProvider` extraction). The
  decision trail for both lives in `HANDOFF-subclassfinder-fix.md`. **Only Finding 2 (P1) remains**
  and is documented below.
- These are local-review findings — never posted to GitHub; the actual GitHub reviewers
  (philipphofmann, NinjaLikesCheez, itaybre, noahsmartin) are positive.
- GitHub activity: no comments, reviews, or mutations were posted
- Code has moved on since the reviewed head (commits through `af5d80427`): `classes(forImage:)` was
  extracted into `SentryImageClassProvider`/`SentryDefaultImageClassProvider`, and gated-class
  discovery/swizzling behavior was documented. Finding 2 below is unchanged by those — the raw
  `__objc_classlist` pointers now flow through the new provider, but they're still unremapped. See
  `HANDOFF-subclassfinder-fix.md` for the full current state.
- Local changes: this doc + `HANDOFF-subclassfinder-fix.md`.

## PR Intent

- Fix GH-8152, where `SentrySubClassFinder` realizes unrelated Swift/Objective-C classes through `NSClassFromString`.
- Class realization can crash older OS versions when Swift metadata references an availability-gated framework type.
- Replace `objc_copyClassNamesForImage` plus `NSClassFromString` discovery with direct reads of the image's `__objc_classlist` Mach-O section.
- Walk superclasses with `class_getSuperclass` without realizing classes.
- Pass discovered `AnyClass` pointers to the main-thread swizzling block.

## Finding 2: Raw Class List Entries Are Unremapped

### Severity

- **P1 / merge blocker**
- The implementation passes class references to swizzling that are not guaranteed to be the live runtime class objects.

### Affected Code

> Note (2026-07-23): the implementation moved out of `SentryDefaultObjCRuntimeWrapper` into
> `SentryDefaultImageClassProvider` (commit `3a3abd444`). Updated references:

- `Sources/Swift/Helper/SentryDefaultImageClassProvider.swift` — `classes(inSection:size:)` and the
  raw-pointer comment (the "we do NOT run objc4's `remapClass`" block).
- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift:52` — receives the raw
  pointers via `imageClassProvider.classes(forImage:)`.
- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift:71,75,87,97` — filters,
  names, collects, and hands the raw pointer to the swizzle `block`.

### Problem

- objc4 defines the entries in the image class list as `classref_t`:

```cpp
// classref_t is unremapped class_t*
typedef struct classref * classref_t;
```

- Apple runtime code calls `remapClass(classlist[i])` before returning or operating on an image class.
- Remapping can:
  - Replace a compiler-emitted class object with a previously allocated future class object.
  - Return `nil` for a class ignored because of a missing weak-linked superclass.
- `classes(inSection:size:)` instead rebinds entries directly to `AnyClass?` and returns them unchanged.
- The direct pointers are then retained across a queue hop and passed to the Sentry swizzler.

### Local Reproduction

- A future class was allocated with `objc_getFutureClass("SentryFutureVictim")`.
- A bundle defining that class was then loaded.
- The raw class-list pointer was compared with the live runtime lookup.
- Result:

```text
future=0x1013451a0 live=0x1013451a0 raw=0x100b480c0
liveName=SentryFutureVictim rawName=SentryFutureVictim
liveSuper=0x1ef149ad8 rawSuper=0x1ef149ad8
runtimeCount=1 first=SentryFutureVictim rawEqualsLive=no
probe_status=10
```

- The raw pointer and live class pointer differ even though their names and superclasses match.
- This is exactly the case handled by objc4's `remapClass` map.

### Why Existing Tests Miss It

- `testClassesForImage_whenReadingEveryLoadedImage_shouldMatchCopyClassNamesForImage` compares sets of class **names**.
- A remapped class and its raw compiler class have the same name.
- The test therefore passes even when pointer identity and runtime validity differ.
- `compactMap` only removes literal null entries; it cannot apply objc4's private remapping table.

### Consequences

- Sentry may swizzle a replaced or ignored class object instead of the live class.
- `SentrySwizzle` deduplication records class object identity in `NSMutableSet<Class>`; raw and live remapped classes have different identities.
- A later swizzle through the live pointer may bypass once-per-class deduplication and apply a second swizzle.
- Runtime operations on ignored or otherwise remapped raw metadata are outside the supported runtime contract.

### Recommended Resolution

- Do not pass raw class-list pointers to the swizzler or retain them across the background-to-main queue hop.
- A safer supported-API design:
  1. Pin/synchronize the image while parsing its class list.
  2. Use raw pointers only transiently for the non-realizing superclass walk.
  3. Store the selected class names, not the raw pointers.
  4. Resolve only the selected `UIViewController` subclasses on the main thread.
  5. Verify `class_getImageName` still matches the requested image before swizzling to avoid same-name cross-image resolution.
- Resolving a selected view-controller class on main does not add a new realization requirement: the swizzling implementation immediately messages and realizes the selected class anyway.
- Add a future-class/remapping regression test; name-set equivalence is insufficient.

### Follow-Up Review of Local Attempt

- Follow-up reviewed on July 21, 2026. (File paths below are as of that review; the raw-pointer
  comment has since moved to `SentryDefaultImageClassProvider.swift` — see "Affected Code".)
- Local changes inspected:
  - Added explanatory comments justifying the intentional use of unremapped pointers (then in `SentryDefaultObjCRuntimeWrapper.swift`).
  - Added `testActOnSubclassesOfViewController_WhenClassDoesNotReachViewController_IsNotSwizzled` in `SentrySubClassFinderTests.swift`.
- Conclusion: **the local attempt does not address Finding 2**.
- No production behavior changed. Raw `__objc_classlist` entries are still returned unchanged, retained across the queue hop, and passed to the swizzler.

#### Disproven Assumption

- The new comment claims a resolved future class is, in practice, never a `UIViewController` subclass.
- objc4 only prevents a future class from being completed by a Swift class. It does not restrict the Objective-C superclass hierarchy of a future class.
- A deterministic local probe reserved `SentryFutureViewController` through `objc_getFutureClass`, then loaded an Objective-C bundle defining it as an `NSViewController` subclass.
- `NSViewController` exercises the same Objective-C runtime remapping behavior as an Objective-C `UIViewController` subclass.
- Result:

```text
future=0x10228ffc0 live=0x10228ffc0 raw=0x1026900b8 rawEqualsLive=no
rawName=SentryFutureViewController liveName=SentryFutureViewController
rawSuper=NSViewController liveSuper=NSViewController
rawIsViewController=yes liveIsViewController=yes
```

- The raw compiler-emitted pointer:
  - Differs from the live runtime pointer.
  - Has a superclass chain reaching the view-controller base class.
  - Passes the same superclass filter used by `SentrySubClassFinder`.
- The current implementation would therefore forward the unremapped raw pointer to the swizzler.

#### Why the Added Test Is Insufficient

- `FakeViewController.self` is a normal, live runtime class pointer. It is not a raw pointer that objc4 remaps to another class or to `nil`.
- The test only reconfirms that an ordinary non-view-controller class is rejected by the superclass walk.
- That behavior was already covered by `testActOnSubclassesOfViewController_IgnoreFakeViewController`.
- The test cannot detect:
  - A raw pointer differing from the live runtime class pointer.
  - A future class whose raw and live pointers share the same name and superclass.
  - Incorrect class-identity deduplication in `SentrySwizzle`.
  - A raw pointer that objc4 would remap to `nil`.
- The updated focused suite passed `10` tests with `0` failures on iOS 18.6, but none of those tests exercises Objective-C class remapping.

#### Finding Status

- **Finding 2 remains open and remains a merge blocker.**
- Documentation asserting that raw pointers are safe is not a replacement for obtaining the live runtime class identity or redesigning the handoff so raw pointers never reach the swizzler.

## Validation Completed

### Tests

- Command:

```bash
IOS_SIMULATOR_OS=18.6 IOS_DEVICE_NAME='iPhone 16 Pro' \
  make test-ios FOR_AGENTS=true \
  ONLY_TESTING=SentryTests/SentrySubClassFinderTests
```

- Result: `9` tests executed, `0` failures.

- Command:

```bash
IOS_SIMULATOR_OS=15.5 IOS_DEVICE_NAME='iPhone 13 Pro' \
  make test-ios FOR_AGENTS=true \
  ONLY_TESTING=SentryTests/SentrySubClassFinderTests
```

- Result: `9` tests executed, `0` failures.
- The iOS 15.5 run is important because the fix targets older runtime/availability behavior.

### CI State Observed

- Fast unit tests and fast framework slice checks were passing.
- Full CI jobs were gated by the missing `ready-to-merge` label because the PR was still a draft.
- Danger, lint, analysis, and security checks observed during review were passing.

### Cross-Platform Build Attempt

- A local tvOS build was attempted with Xcode 26.6 and the installed tvOS 26.5 simulator.
- It failed during Swift package binary-artifact resolution before compilation:

```text
downloaded archive of binary target ... does not contain a binary artifact
xcodebuild: error: Could not resolve package dependencies
```

- This failure appears unrelated to the PR and does not provide tvOS compilation evidence.
- Raw diagnostics are in `raw-build-output.log` from the review session.

### arm64e Evidence

- The PR author tested an arm64e build on a physical iPhone 12 running iOS 26.5.
- The sample read and swizzled classes without pointer-authentication failures.
- This is useful evidence for PAC handling.
- It does not cover concurrent unload or Objective-C class remapping.

## Suggested Implementation Sequence (Finding 2, if picked up)

1. Stop carrying raw `__objc_classlist` pointers across the background→main queue hop, or apply a
   `remapClass`-equivalent to each entry (skipping nil) before they reach the swizzler.
2. Do it without reintroducing the GH-8152 realization crash (no `NSClassFromString` re-resolution).
3. Add a future-class/remapping regression test — needs an ObjC bundle + `objc_getFutureClass`
   (no such harness exists yet); name-set equivalence is insufficient.
4. Re-run iOS 15.5 and current iOS tests; build tvOS, visionOS, Catalyst, watchOS slices.
5. Re-run format and analysis before merge.

## Review Conclusion

- The PR fixes the normal availability-crash path in the tested configurations.
- **Only Finding 2 remains** (unremapped raw `__objc_classlist` pointers reach the swizzler); it is a
  runtime-correctness concern, not a style one, demonstrated locally. Deferred by user decision and
  tracked as a known-limitation code comment. Findings 1 and 3 were resolved and removed from this
  document (see the Status update at the top and `HANDOFF-subclassfinder-fix.md`).
