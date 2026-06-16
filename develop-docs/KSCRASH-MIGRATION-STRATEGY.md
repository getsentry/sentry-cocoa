# KSCrash Migration Strategy

Date: June 16th 2026
Author: @NinjaLikesCheez <thomas.hedderwick@sentry.io>

## Background

We're migrating from `SentryCrash` (a KSCrash v1.x fork with renamed identifiers) to KSCrash 2.x. The new integration (`SentryKSCrashIntegration`) is being built alongside the existing `SentryCrashIntegration`. We need a strategy for how these two coexist during development and how the cutover happens.

---

## Option A: Long-lived feature branch

Keep all KSCrash work on a dedicated branch (`kscrash-*`) and merge back to `main` in one big-bang PR when complete.

**Pros**

- No impact on `main` until work is done
- Freedom to iterate without gating concerns

**Cons**

- Long-lived branches diverge; merge conflicts galore
- The final merge PR is large, hard to review, and risky to ship
- Other teams (React Native, Flutter, Unity) have to swap branches to test

---

## Option B: Dual integrations on `main` (proposed)

Ship both `SentryCrashIntegration` and `SentryKSCrashIntegration` on `main`. They are mutually exclusive at runtime — only one installs its crash handlers. Which one runs is controlled by two guards:

1. `**#if SDK_V10` compiler flag** — `SentryKSCrashIntegration` is compiled into the binary only when building for V10.
2. `**options.experimental.enableKSCrashIntegration`** — an opt-in flag (also gated behind `#if SDK_V10`) that must be `true` for `SentryKSCrashIntegration` to install. `SentryCrashIntegration` checks this flag and skips installation when the KSCrash path is active.

**Pros**

- Work ships incrementally to `main`; no merge cliff & conflict mess
- Hybrid SDK consumers can test against the KSCrash path and swap between the two more easily
- The cutover becomes a 'flip the switch' change
- Easier code review — changes land in small, reviewable chunks

**Cons**

- Both integrations live in the codebase simultaneously for a period
- `#if SDK_V10` guards add a small amount of conditional-compilation mental noise for developers
- SPM users will checkout KSCrash as a dependency, whether it's used or not

---

## Proposal: Option B

The dual-integration approach is lower risk and produces a better end result. The `SDK_V10` flag already exists in the build system.

**Cutover plan (when KSCrash integration is feature-complete):**

1. Remove `enableKSCrashIntegration`
2. Remove the `#if SDK_V10 guards`
3. Update SentryKSCrashIntegration to use the traditional `enableCrashHandler` option as it's enable guard
4. Remove SentryCrash altogether
