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
  (confirmed iOS 16.4; repro = the committed `SubClassFinderRegressionViewController` + UITest). Likely
  fix: defer swizzling to first instantiation. Two guard spikes already tried and rejected — don't
  re-spike (see `REVIEW-PR-8457.md`).
- **Finding 2 — unremapped raw `__objc_classlist` pointers** reach the swizzler; can double-swizzle a
  remapped class. Narrow. Fix without reintroducing the GH-8152 realization crash.

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
