# Annual Apple OS Compatibility Testing

Every summer at WWDC, Apple announces the next OS generation and ships the first Xcode beta. Between that beta and the public release we make sure the SDK still builds, launches, and reports telemetry — and fix what doesn't.

Copy [the template](#linear-project-template) into a new Linear project each cycle. Everything after it is reference you read once.

## Overview

The cycle hangs off Apple's milestones, not calendar dates: work starts at the **first beta**, the
manual sweep runs again — narrower — at the **release candidate**, CI flips to the new OS at **GA**,
and customer data gets checked a month after that. In between, beta CI carries the load; that's why
nobody re-runs the sweep by hand for every beta.

## Linear Project Template

One task per phase. Platforms and suites are acceptance criteria inside a task, not separate issues.

```markdown
> Risk areas and triage rules: `develop-docs/ANNUAL_OS_COMPATIBILITY.md`

## 1. Triage Apple's changes — First beta

- [ ] Close last cycle's open validation issues that aren't in a known risk area
- [ ] Review WWDC sessions and release notes against the known risk areas
- [ ] File one issue per area needing validation, each with its own acceptance criteria
- [ ] Decide which features earn a manual check this cycle

## 2a. Beta build CI — First beta

- [ ] Copy last cycle's `xcode<NN>-test.yml` in `.github/workflows/`, bump the version
- [ ] Confirm the `xcode-beta` pool has the new Xcode — it's ours, so this is a request, not a wait
- [ ] Add a matching `run_xcode<NN>_for_prs` filter to `.github/file-filters.yml`

## 2b. Beta runtime test CI — First beta to RC

Enable the tests on beta CI and fix everything until they're green. They don't block PRs yet, so
nothing forces you to look — but phase 5 can only require what's already green.

- [ ] Run the unit-test and critical-UI matrices on beta Xcode and the new runtimes
- [ ] Move slow platforms to `nightly-test.yml`
- [ ] Keep new-OS jobs non-blocking; the previous generation stays required
- [ ] Fix each failure at its cause: the test (beta runtime differs), the SDK (real regression), or a workaround (toolchain bug)

## 3a. Toolchain sweep — First beta

Run all of these on beta Xcode. Point the shell at it first, for example
`export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`, and confirm with
`xcodebuild -version`.

- [ ] `make build` + `make test`
- [ ] `make analyze`
- [ ] `make build-v10` + `make test-v10`, while a next major is in flight
- [ ] `make build-samples` (must be warning-free — and diff its list against `ls Samples/`, it misses directories), `make test-samples-ui`, `make test-ui-critical`
- [ ] `./TestSamples/CrashE2E/run-crash-e2e.sh --platform all` (manual — `all` selects only iOS and macOS, not all Apple platforms; nothing in CI runs it)
- [ ] `./TestSamples/SwiftUICrashTest/test-crash-and-relaunch.sh`
- [ ] `make build-xcframework-dynamic` + `make build-xcframework-static`
- [ ] Triage every error and warning: does it also happen on stable Xcode?
- [ ] File a follow-up if the new Xcode forces a deployment-target bump — it's a breaking change with its own release process, and React Native, Flutter, .NET, and Unity need advance warning
- [ ] Record Xcode build, host OS, and runtime or device for each run

## 3b. Risk-area validations — Before RC

- [ ] Every issue filed in phase 1 is closed, or carried over with its findings written down

## 3c. Runtime telemetry check — First beta

Launch each sample on the new runtime, exercise its actions, and confirm in Sentry that the events
arrive intact — message, error with a tag, exception, breadcrumbs, transaction with child spans,
navigation and load spans, metrics. Stamp every sample with the same cycle-unique build number so
the set queries together, and check app identifier, OS version, and device family on one full event.

- [ ] iOS — `iOS-Swift`
- [ ] iOS SwiftUI — `iOS-SwiftUI`
- [ ] iOS Objective-C — `iOS-ObjectiveC`
- [ ] tvOS — `tvOS-Swift`
- [ ] watchOS — `watchOS-Swift`
- [ ] visionOS — `visionOS-Swift`
- [ ] macOS — `macOS-Swift` (after GA — macOS betas can't be tested)

## 3d. Test-debt audit — Before RC

- [ ] Grep for skips, exclusions, and target-membership exceptions added in past cycles
- [ ] Confirm each selected suite actually executes tests rather than zero
- [ ] Re-enable, or record why it stays off

## 4. Release-candidate validation — RC

Keep all RC work in this checklist so it has one owner.

- [ ] Run the full beta-Xcode CI matrix against the RC Xcode and runtimes, including analyzer, unit-test, and critical-UI jobs
- [ ] Repeat what CI doesn't cover: samples, crash E2E, xcframeworks, and the phase 3c telemetry check
- [ ] Triage everything that changed since the first beta

## 5. Make new-OS CI required — GA

- [ ] Only require jobs that have been stable — a job still red or flaky isn't ready
- [ ] Every remaining failure in the new-OS jobs has a triage outcome
- [ ] Make new-OS jobs required, retire the previous generation from the blocking set

## 6. Check customer data — GA + 30 days

A comparison query, not a test pass. It runs a month after everything else shipped, when the
project already feels finished — and it has slipped every year it's been tried.

- [ ] As soon as GA is scheduled, set this task's due date to GA + 30 days
- [ ] Compare per-feature event volume on the new OS against the previous generation
- [ ] Spot-check quality: symbolicated frames, app-start durations, replays, span trees
- [ ] File an issue for anything that stopped reporting or reports malformed data
```

## Known Risk Areas

Start validation here — where the SDK has broken before, plus the areas we keep having to re-check.

- **App lifecycle** — iOS 27 apps fail to launch without `UIScene` adoption ([TN3187](https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle)); broke nearly every sample ([#8351](https://github.com/getsentry/sentry-cocoa/pull/8351)).
- **Session Replay masking** — the most fragile area, two years running. Liquid Glass silently broke SwiftUI masking in iOS 26 ([#6390](https://github.com/getsentry/sentry-cocoa/issues/6390)). iOS 27 changed UIKit and SwiftUI rendering internals ([#8768](https://github.com/getsentry/sentry-cocoa/pull/8768)), and a masking fixture that had reliably produced clipping regions produced none ([#8744](https://github.com/getsentry/sentry-cocoa/pull/8744)). Check the touch overlay and Replay's network capture too.
- **Simulator image paths** — xOS 27 runtimes moved to a cryptex mount; our duplicate-SDK validator scanned them on the shared queue and starved launch profiling ([#8576](https://github.com/getsentry/sentry-cocoa/pull/8576)).
- **Runtime discovery and swizzling** — Apple's Swift networking rewrite prompted a full `NSURLSession` census; it found no swizzling change was needed ([#8127](https://github.com/getsentry/sentry-cocoa/issues/8127)). The `AsyncImage` HTTP-caching follow-up remains open ([#8739](https://github.com/getsentry/sentry-cocoa/issues/8739)).
- **Swift compiler and language mode** — each Xcode can introduce stricter concurrency diagnostics, new warnings, and source breaks before runtime tests start. Exercise Swift 6 consumers with `iOS-Swift6` and `iOS-Cocoapods-Swift6`, plus `make build-v10` while the next major is in flight.
- **Downstream hybrid SDKs** — React Native, Flutter, .NET, and Unity consume this SDK and its private APIs on their own release schedules. Warn and validate them before changing deployment targets, build products, or shared API.
- **App start and prewarming** — needs a physical device without a debugger, and Apple offers no public trigger or detection API, so it can't be reproduced naturally; inject `ActivePrewarm=1` against a suspended process instead ([#8129](https://github.com/getsentry/sentry-cocoa/issues/8129)). The harness and results live on branch [`test/os-27-prewarm`](https://github.com/getsentry/sentry-cocoa/tree/test/os-27-prewarm) — `Samples/OS27-Prewarm` on `main` is an empty shell.
- **Samples** — each new Xcode flags newly deprecated API, malformed XcodeGen refs, and missing platform assets ([#8724](https://github.com/getsentry/sentry-cocoa/pull/8724)).

## Deciding What to Test

**You do not manually re-test every feature on every platform.** A feature earns a manual
end-to-end check only if:

1. Triage flagged an Apple change it depends on — the main input;
2. it has no automated coverage on that platform;
3. it sits in a known risk area; or
4. it broke in a previous cycle.

Everything else rides on the suites running against the new runtime, plus 3c's shallow telemetry
pass on every platform.

Do the exhaustive feature-by-platform sweep only when the UI or runtime foundation shifts, as iOS
26's Liquid Glass did. A normal year doesn't need it.

> [!WARNING]
> Never mark a feature "covered on another platform, we'll confirm with customer data." Either it's
> checked somewhere concrete, or it's untested.

## Finding Triage

Applies to tests and samples alike:

| Beta   | Stable | Meaning              | Action                                    |
| ------ | ------ | -------------------- | ----------------------------------------- |
| fails  | passes | New-OS regression    | Fix inside this project                   |
| fails  | fails  | Pre-existing         | File a follow-up; do not fix here         |
| passes | fails  | Stable-only breakage | File a follow-up; unrelated to this cycle |

Warnings count the same way. In a public header a new deprecation reaches customer builds; in a
sample it's an early signal that Apple deprecated something we still use, and build noise hides
real breakage. Either way a beta-only warning is a finding, not noise to defer
([#8124](https://github.com/getsentry/sentry-cocoa/issues/8124)).

Fix before OS launch anything that blocks building, linking, or launching; crashes or hangs a host
app; breaks supported telemetry; or blocks required tests. Everything else is a follow-up. When
validation confirms expected behavior, write that conclusion down too, so next cycle doesn't redo
the investigation. If a runtime or device is unavailable, mark the work blocked — not passed.

## Where Things Live

Read inventories from source — `make help`, `Plans/*.xctestplan`, `.github/workflows/`,
[BUILD.md](BUILD.md), [TEST.md](TEST.md), [CI.md](CI.md). Copied into a doc, they drift within a
release or two.
