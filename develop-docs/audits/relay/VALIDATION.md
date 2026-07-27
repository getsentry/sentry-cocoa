# Validation — Cocoa ↔ Relay audit self-test

The audit itself needs a regression test: a pinned historical commit containing a real, serious conformance bug that a correct audit run MUST surface. If a validation run misses it, the audit — not the SDK — is broken.

## The pinned target

- **Commit:** `b557385bd02ba527f02b4b754caa056714c20274` (`build: remove podspec files (#8298)`) — the parent of the [#8324](https://github.com/getsentry/sentry-cocoa/pull/8324) merge, i.e. the last `main` commit **before** the rate-limit header fix.
- **The bug present at that SHA (= RELAY-001):** `Sources/Swift/Networking/DefaultRateLimits.swift` `update(_:)` read `response.allHeaderFields["X-Sentry-Rate-Limits"]` and `["Retry-After"]` — case-sensitive subscripts. Over HTTP/2/3 (header names lowercased on the wire) both lookups return nil, so a 429 fell through to the all-categories fallback and the SDK **rate-limited all telemetry** (issue [#8322](https://github.com/getsentry/sentry-cocoa/issues/8322)).

## When to run

- Manually (claude.ai one-off run / "run now"), whenever `AUDIT.md`, `SURFACE_MAP.md`, or `ROUTINE_PROMPT.md` change materially, or the routine's model changes.
- Not on the weekly schedule — the weekly run audits `main` only.

## Procedure

1. Check out sentry-cocoa `main` (for this audit config) and create a **second worktree at the pinned SHA**:
   `git worktree add /tmp/cocoa-prefix-validation b557385bd02ba527f02b4b754caa056714c20274`
   The audit config in `develop-docs/audits/relay/` is read from the `main` checkout; the **audited code** is the old worktree (these files don't exist at the pinned SHA).
2. Run the full `AUDIT.md` procedure against the old worktree, classifying against `FINDINGS.md` from `main` as usual.
3. Because RELAY-001 is a `fixed` tombstone in `FINDINGS.md`, the old code must classify it as a **REGRESSION (NEW / HIGH)**.

## Pass / fail criteria

- **PASS:** the report contains a NEW/HIGH REGRESSION finding located at `Sources/Swift/Networking/DefaultRateLimits.swift`, describing case-sensitive reads of `X-Sentry-Rate-Limits` and/or `Retry-After` (matching RELAY-001's fingerprint). Findings that were open at that SHA and are triaged in `FINDINGS.md` (e.g. the SentryNetworkTracker Content-Type reads, RELAY-002/003 — also `fixed` tombstones now) appearing as additional REGRESSIONs is expected and fine.
- **FAIL:** RELAY-001 is missing, reported below HIGH, or classified as anything other than NEW/REGRESSION. The run must end its Slack post / output with `VALIDATION FAILED`, and must NOT post a normal weekly-style report.
- Prefix all validation output with `🧪 VALIDATION RUN` (see `REPORT_FORMAT.md`) so it is never mistaken for a real drift report.

## Sanity companion

After a validation run, confirm the inverse: a normal run against current `main` must NOT report RELAY-001 (or any `fixed` tombstone) — expected result is "no new drift" with all registry entries classifying as KNOWN.

## Cleanup

`git worktree remove /tmp/cocoa-prefix-validation`
