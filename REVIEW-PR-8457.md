# PR 8457 — open findings (still to do)

Tracks the crash edge cases PR #8457 (`fix: prevent SubClassFinder availability crash`) does **not**
fix. Both are deferred, kept as known-limitation comments in the code (the mechanism lives there — see
`SentryDefaultImageClassProvider.swift` and the `actOnSubclassesOf` call site in
`SentryUIViewControllerSwizzling.swift`). This doc only lists what remains.

## Finding 4: gated view-controller subclass still crashes at swizzle time (OPEN, deferred)

- **What:** discovery no longer realizes classes, but the selected `UIViewController` subclasses are
  still swizzled, and swizzling realizes them. A Swift VC subclass gated to a newer OS with a stored
  property of a gated newer-framework type (e.g. `@available(iOS 17) VC { var x: CapturedStructure? }`)
  crashes at swizzle time (`EXC_BAD_ACCESS` in Swift metadata completion). Confirmed on the iOS 16.4
  simulator; reproduced by the committed `SubClassFinderRegressionViewController` +
  `SubClassFinderRegressionUITests` (the acceptance gate for any fix).
- **Why no cheap guard (don't re-spike these):** skipping not-yet-realized classes skips ~100% of VCs
  at SDK start (none realized yet → no instrumentation); probing `swift_checkMetadataState` itself
  drives initialization and crashes the same way. No crash-free per-class signal exists at SDK start.
- **Recommended fix:** defer swizzling a discovered subclass to its **first instantiation**, so a
  never-instantiated gated VC is never realized. Larger change; revisits the initializer-swizzling
  area the SDK moved away from (GH-1355). Validate against the iOS 16.4 repro.

## Finding 2: raw `__objc_classlist` entries are unremapped (OPEN, deferred)

- **What:** `classes(inSection:size:)` returns the raw compiler-emitted class pointers without objc4's
  `remapClass`, and `SentrySubClassFinder` carries them to the swizzler. For a class objc4 remaps (a
  resolved future class, or a weak-linked class it maps to nil), the raw entry differs from the live
  class, which can bypass `SentrySwizzle`'s class-identity dedup and double-swizzle. Reachable in
  practice only for an Objective-C future VC subclass — narrow.
- **Constraint on any fix:** must NOT reintroduce the GH-8152 realization crash. Re-resolving by name
  (`NSClassFromString`) realizes the class and can pick a same-named class from another image — the
  exact behavior this PR removed. A viable fix applies a `remapClass`-equivalent per entry (skipping
  nil) transiently, keeping the non-realizing path.
- **Test gap:** name-set equivalence is insufficient; a real regression test needs an Objective-C
  bundle + `objc_getFutureClass` to exercise remapping and pointer identity.
