# PR 8457 Local Review Handoff

## Review Status

- PR: `https://github.com/getsentry/sentry-cocoa/pull/8457`
- Title: `fix: prevent SubClassFinder availability crash`
- Reviewed head: `6e8284f8718f1fc665bafbb10ea545c8f08c7ec3`
- Base during review: `main` at `6d9248043b5919d9b675d9e743188924b44b6bf6`
- Review date: July 21, 2026
- Original verdict: **Do not merge yet** (Findings 1 P0, 2 P1, 3 P2)
- Status update (2026-07-23): **Finding 3 resolved** (compiler directives — see its section);
  **Findings 1 & 2 deferred by user decision**, kept as known-limitation code comments (not GitHub
  issues). These are local-review findings — never posted to GitHub; the actual GitHub reviewers
  (philipphofmann, NinjaLikesCheez, itaybre, noahsmartin) are positive.
- GitHub activity: no comments, reviews, or mutations were posted
- Local changes from review: this doc + `HANDOFF-subclassfinder-fix.md`

## PR Intent

- Fix GH-8152, where `SentrySubClassFinder` realizes unrelated Swift/Objective-C classes through `NSClassFromString`.
- Class realization can crash older OS versions when Swift metadata references an availability-gated framework type.
- Replace `objc_copyClassNamesForImage` plus `NSClassFromString` discovery with direct reads of the image's `__objc_classlist` Mach-O section.
- Walk superclasses with `class_getSuperclass` without realizing classes.
- Pass discovered `AnyClass` pointers to the main-thread swizzling block.

## Finding 1: Concurrent Image Unload Can Crash

### Severity

- **P0 / merge blocker**
- Violates the SDK requirement to never crash the host application.

### Affected Code

- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift:28`
- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift:32`
- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift:36`
- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift:56`
- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift:65`

### Problem

- `classes(forImage:)` iterates `_dyld_image_count`, matches an image name, obtains a Mach-O header, obtains a section pointer, and copies class pointers.
- The image is not pinned and no loader/runtime synchronization protects the header or section memory.
- An unload can occur after any of these operations:
  - `_dyld_get_image_name(index)`
  - `_dyld_get_image_header(index)`
  - `getsectiondata(...)`
  - before or during `UnsafeBufferPointer(...).compactMap`
- The installed Apple SDK header explicitly documents this iteration as not thread-safe:

```c
/*
 * The following functions allow you to iterate through all loaded images.
 * This is not a thread safe operation. Another thread can add or remove
 * an image during the iteration.
 */
```

- Local header inspected:
  - `/Applications/Xcode-16.4.0.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.5.sdk/usr/include/mach-o/dyld.h:51`
- The PR comments currently claim `_dyld_get_image_header` and `_dyld_get_image_name` acquire a loader read lock and that stale indices safely return `nil`. Those claims are not supported by the public API contract.
- The old `objc_copyClassNamesForImage` implementation is materially safer. Modern objc4 uses the runtime lock plus Mach-O UUID validation to avoid concurrent-unload ABA problems before reading an image's class list.

### Deterministic Reproduction

- A temporary Objective-C `MH_BUNDLE` containing a class was built locally.
- The probe performed these steps:
  1. `dlopen` the bundle.
  2. Find and retain its raw Mach-O header pointer using `_dyld_get_image_header`.
  3. `dlclose` the bundle so it is unmapped.
  4. Call `getsectiondata` using the stale header.
- Result:

```text
before=45 loaded=348 index=45 header=0x1002dc000
after=347 afterIndex=-1 afterHeader=0x0
probe_status=139
```

- Exit status `139` is `SIGSEGV`.
- This demonstrates that an Objective-C image can unload and that dereferencing the saved header or section is unsafe.
- The production race window also extends through the entire class-pointer copy, not only the `getsectiondata` call.

### Required Resolution

- Do not dereference an image header or section unless image lifetime is guaranteed for the complete operation.
- Use a mechanism that safely coordinates with image loading/unloading and validates that the header still represents the requested image.
- Possible directions requiring careful validation:
  - Use the SDK's binary-image cache/callback infrastructure with appropriate synchronization and image removal handling.
  - Pin the target image for the operation and independently verify the header-to-path association before dereferencing it.
  - Use an Objective-C runtime API that already owns the necessary runtime lock and remapping behavior, if a supported API is available.
- Merely reading `_dyld_image_count` once does not solve this issue.
- Add an unload-race test using an Objective-C bundle or an equivalent deterministic harness.

## Finding 2: Raw Class List Entries Are Unremapped

### Severity

- **P1 / merge blocker**
- The implementation passes class references to swizzling that are not guaranteed to be the live runtime class objects.

### Affected Code

- `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift:74`
- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift:50`
- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift:67`
- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift:85`
- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift:93`

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

- Follow-up reviewed on July 21, 2026.
- Local changes inspected:
  - Added explanatory comments at `Sources/Swift/Helper/SentryDefaultObjCRuntimeWrapper.swift:56` justifying the intentional use of unremapped pointers.
  - Added `testActOnSubclassesOfViewController_WhenClassDoesNotReachViewController_IsNotSwizzled` at `Tests/SentryTests/Integrations/Performance/SentrySubClassFinderTests.swift:157`.
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

## Finding 3: Required SPI Protocol Method Breaks Old Conformers

### Severity

- **P2 / compatibility risk**
- Potential unrecognized-selector host crash for an injected conformer built against an older SDK.

### Affected Code

- `Sources/Swift/Helper/SentryObjCRuntimeWrapper.swift:21`
- `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift:50`
- `Sources/Swift/SentryDependencyContainer.swift:161`

### Problem

- `classesForImage:` is added as a required method to the public Objective-C SPI protocol `SentryObjCRuntimeWrapper`.
- `SentryDependencyContainer.objcRuntimeWrapper` is publicly settable through the private SPI surface.
- The new method is called unconditionally.
- An Objective-C conformer compiled against the previous SDK can still be supplied at runtime but does not implement `classesForImage:`.
- Calling the new selector on that object causes an unrecognized-selector exception.

### Scope Check

- A read-only GitHub code search across the `getsentry` organization found no external source conformers beyond `sentry-cocoa` tests.
- This lowers the known exposure but does not eliminate private, customer, or downstream SPI users.

### Recommended Resolution

- Avoid adding a required method to the existing SPI protocol.
- Options:
  - Introduce a separate internal capability protocol used only by the default implementation.
  - Make the Objective-C requirement optional and implement an explicit safe fallback.
  - Remove this operation from the injectable wrapper if injection is not needed.
- The fallback must not restore the original unsafe realization of every class.

### Verification Verdict (2026-07-21)

- **Verdict: TRUE — the mechanism is confirmed, and the P2 severity is correct.**
- Every link in the chain was verified first-hand against the working tree, the diff vs base (`6d9248043`), the generated public header, and the test conformer.

#### Evidence

- **Required method, called unconditionally.** The method is added with no `optional` keyword, and the file has no `optional` anywhere:
  - `Sources/Swift/Helper/SentryObjCRuntimeWrapper.swift:22` (`@objc(classesForImage:)` + `func classes(forImage:)`)
  - `Sources/Swift/Core/Integrations/Performance/SentrySubClassFinder.swift:50` calls it directly; there is no `respondsToSelector` / optional guard anywhere in the Swift layer.
- **Reachable by external Objective-C conformers.** The protocol is `@objc @_spi(Private) public` and is emitted into the shipped `Sentry.framework/Headers/Sentry-Swift.h` as a plain `@protocol SentryObjCRuntimeWrapper` with **no SPI guard**.
  - `develop-docs/SWIFT.md:47` confirms `@_spi(Private)` restricts _Swift_ importers only; it has no effect for Objective-C.
  - `Sources/Swift/SentryDependencyContainer.swift:161` exposes the setter as `@objc public var objcRuntimeWrapper` (readwrite in the header).
- **Old conformers really are missing the method (smoking gun).** The repo's own Objective-C conformer had to _add_ `classesForImage:` under the same `#if`:
  - `Tests/SentryTests/Helper/SentryTestObjCRuntimeWrapper.m:68`
  - Objective-C only _warns_ (never errors) on incomplete protocol conformance, so a conformer built before this PR compiles and links, then hits `doesNotRecognizeSelector:` when the new SDK invokes the selector.
- **Default-on trigger path.** The swizzling path that reaches this call is enabled by default:
  - `Sources/Swift/Options.swift:257` (`enableAutoPerformanceTracing = true`), `Sources/Swift/Options.swift:280` (`enableUIViewControllerTracing = true`), `Sources/Swift/Options.swift:446` (`enableSwizzling = true`).

#### Severity Note

- P2 is correct — not higher. The finding's own scope check holds: the only realistic external consumers are hybrid SDKs, and none conform to this protocol. The method is also platform/arch-gated (`#if (os(iOS) || os(tvOS) || os(visionOS)) && (arch(arm64) || arch(x86_64))`), so watchOS/macOS/32-bit slices are unaffected regardless. Real latent ABI hazard, small blast radius.

#### Wording Refinement

- The risk is **Objective-C** conformers only. A _Swift_ conformer would fail to **compile** against the new required method, so it can never reach runtime. Read the finding's "compiled against the previous SDK" as Objective-C-only.

#### Resolution Applied (2026-07-23)

Fixed with **compiler directives**, keeping the method **required** (the `@objc optional` +
`respondsToSelector:` skip fallback was considered and deliberately rejected):

- `classes(forImage:)` stays a required member under its existing gate `#if (os(iOS) || os(tvOS) || os(visionOS)) && (arch(arm64) || arch(x86_64))`; its doc note explains the `#if`-not-`optional` rationale.
- The sole caller `SentrySubClassFinder` and the `SentryUIViewControllerSwizzling` that holds it gained the matching `&& (arch(arm64) || arch(x86_64))` on their file-level `#if`, so caller and method now exist on exactly the same slices. The cascade stops there (`SentryDependencyContainer` / `SentryPerformanceTrackingIntegration` reference these inside regions already gated to those platforms).
- No test added and no `SentryObjC`/`SentryObjCCompat` change; `make generate-public-api` produced no diff (SPI).

**Scope — precise:** this hardens the **compile-time** contract (gates are now consistent; any conformer compiled against this SDK version must implement the method or fail to build) and closes the gate mismatch. It does **not** add a runtime guard for a _foreign_ Objective-C conformer compiled against an _older_ SDK and injected via `objcRuntimeWrapper` — that object never sees our `#if`, so a direct call would still `doesNotRecognizeSelector:`. Accepted because it's SPI and the org-wide search found no external conformers; only `@objc optional` + `responds(to:)` would close that residual vector. Revisit if a real external conformer ever appears.

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

## Suggested Implementation Sequence

1. Design a loader-safe image lifetime strategy.
2. Stop carrying raw class references to main.
3. Resolve selected names on main and validate image identity.
4. Preserve compatibility for existing runtime-wrapper conformers.
5. Add unload and future-class regression tests.
6. Re-run iOS 15.5 and current iOS tests.
7. Build tvOS, visionOS, Catalyst, and watchOS slices.
8. Re-run format and analysis before merge.

## Review Conclusion

- The PR fixes the normal availability-crash path in the tested configurations.
- The current implementation replaces a runtime-managed, unload-aware enumeration path with direct parsing that lacks image lifetime protection and class remapping.
- Both gaps are runtime correctness issues, not theoretical style concerns.
- The unload crash was reproduced locally and the remapped-pointer mismatch was demonstrated locally.
- Address Findings 1 and 2 before marking the PR ready to merge.
