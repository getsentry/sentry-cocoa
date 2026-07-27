---
name: relay-conformance-audit
description: Audit the Cocoa SDK for protocol-conformance drift against Relay (getsentry/relay) — hard-coded strings/wire formats that must match Relay exactly and fail silently when they don't (the class behind #8322, the case-sensitive rate-limit header). Read-only; outputs a report, never fixes code. Use for the scheduled weekly check or on demand after networking/protocol changes.
---

# Cocoa ↔ Relay conformance audit

The SDK hard-codes many strings and wire formats that must match Relay exactly — header names, envelope item types, data categories, discard reasons, DSC keys, session fields. A mismatch anywhere in that surface fails **silently**: data is dropped, mis-routed, or miscounted with no error. This skill audits that entire surface. One motivating example of the class: [#8322](https://github.com/getsentry/sentry-cocoa/issues/8322) (a case-sensitive `X-Sentry-Rate-Limits` header read silently rate-limited all telemetry) — but the skill exists to hunt bugs _like_ it, wherever they occur, not that one bug.

**READ-ONLY toward the SDK.** Never edit SDK code or file issues. Never modify `references/findings.md`. The only outputs are the report and — sole exception — a draft PR from the coverage check that touches nothing but `references/surface-map.md` (see "Coverage check").

## Model

Every run reports the **full current list of mismatches** — no delta tracking, no run-to-run memory. A mismatch leaves the report only by being **fixed** or **ignored**:

- **Tracked** — a GitHub issue exists; listed in `references/findings.md`. Reported with its issue link.
- **Ignored** — listed in `references/findings.md` with an explicit _ignore-scenario_. Omitted from the report (counted only) while the scenario holds; reported as needs-action when it no longer holds.
- **Needs action** — everything else. Reported with a pre-filled create-issue link; reappears every run until someone files the issue (→ tracked) or adds it to the ignore list.

If a tracked or ignored entry no longer reproduces, say so — humans can close the issue / prune the list.

## Procedure

1. Record `git rev-parse --short HEAD` and `date +%Y-%m-%d` via shell (never hardcode); both stamp the report.
2. For each area in `references/surface-map.md`, spawn one read-only subagent (parallel). Contract: fetch the listed Relay source / develop-docs pages, read the listed Cocoa files, diff per the area's notes. Return mismatches as `{area, severity HIGH|MEDIUM|LOW, file + symbol, exact wire strings, spec citation, failure mode}`. Severity = silent blast radius, not fix effort. In parallel with these, spawn the coverage-check subagent (see "Coverage check").
3. Match each mismatch against `references/findings.md` on fingerprint (`area + file + normalized summary` — never line numbers, never severity: severity ratings vary between runs, fingerprints are the stable key): tracked / ignored (verify the ignore-scenario still holds) / needs action.
4. Build the report (below), appending the coverage-check result, and deliver: post to Slack when a connector is configured, otherwise print. If a Slack post fails, print everything and state loudly the post FAILED — never report success on a failed post.

## Coverage check (surface-map self-audit)

The audit only inspects what the surface map lists, so a stale map is a silent coverage hole. Every run, one extra subagent checks the map itself — from both directions:

- **SDK side:** list protocol-relevant code the map does NOT reference. Grep the SDK for wire-emitting surfaces: `serialize` implementations feeding envelopes, envelope item construction, `setValue(_:forHTTPHeaderField:)` / header reads, files under `Sources/Swift/Networking/` and `Sources/Swift/Protocol/`, new integrations writing envelope items. Compare against the files the map lists; report unlisted ones that put bytes on the wire.
- **Relay side:** for each Relay/spec source the map cites, check it still exists (note moved paths) and skim Relay's protocol enums (`DataCategory`, `ItemType`, discard reasons, DSC keys) for members added since the map's checks were written that no area would catch.
- Ignore non-wire code (`SentryCrash/` internals, UI, tests) — the bar is "could a mismatch here silently corrupt what Relay receives?".

Outcome:

- **Map up to date** → one line in the report: `coverage: OK`.
- **Gaps found** → list them in the report under `coverage: GAPS`, and prepare a **draft PR** that updates ONLY `references/surface-map.md` (extend an area's file list, fix a moved Relay path, or add a new area with files/spec/checks). Branch `chore/relay-audit-surface-map-<date>`, title `chore: update relay-audit surface map`, `#skip-changelog`, body = the gap list + why each belongs in the map. This is the skill's only permitted write: never touch SDK code, `findings.md`, or SKILL.md in that PR; never merge it — a human reviews. If a draft PR from a previous run is still open, update that branch instead of opening a second one.
- Gaps are NOT mismatches: report them in the coverage section only; the newly-discovered files get audited by the next run after the map PR merges.

## Report

Main message (Slack mrkdwn — no tables, `*bold*`, `` `code` ``), severity-sorted:

```
:shield: *Cocoa ↔ Relay conformance* — <DATE> · sentry-cocoa@<SHA>
mismatches <n> (<n> need action) · ignored <n> · coverage <OK|GAPS: draft PR link>

:warning: *Needs action* (file the issue or add to the ignore list)
• [HIGH] <area> — <file (symbol)> — <one-line summary> — <create-issue link>

:ticket: *Tracked*
• #<issue> <area> — <one-line summary>
```

Everything tracked or ignored: `:white_check_mark: Nothing needs action. (tracked <n> · ignored <n>)`

Thread reply 1 — **TLDR**: per needs-action mismatch, 2–4 plain sentences for a human deciding whether to care — what broke, user impact, blast radius. No file paths, no jargon.

Thread reply 2 — **full detail**: per needs-action mismatch, everything an agent needs to pick it up cold — location (file + symbol), exact wire strings, spec/Relay citation, failure mode, 1–3 verify steps. End with one line noting any tracked/ignored entries that no longer reproduce, and the coverage-check result (gap list + draft-PR link when there are gaps).

Create-issue links: `https://github.com/getsentry/sentry-cocoa/issues/new?title=<urlenc>&body=<urlenc>&labels=Relay-Conformance` — body = the mismatch's full-detail block + "Found by relay-conformance-audit, <DATE>, @<SHA>. After filing: add this issue to skills/relay-conformance-audit/references/findings.md." Keep the URL <8000 chars; trim body to failure mode + Slack-thread pointer if needed.

## Guardrails

- Report only real wire-level mismatches. Style issues, dead code, and things Relay normalizes server-side are ignore-list material, not weekly noise.
- Relay paths move: if a listed path 404s, search the Relay repo for the symbol (`ItemType`, `DataCategory`, `ClientReport`) and audit against the moved file; the coverage check turns the path fix into a draft PR.
- Bounded cost: one subagent per area plus one coverage-check subagent; don't recurse into `SentryCrash/` or other non-protocol code.

## Validation (self-test)

Whenever this skill or the surface map changes materially, validate the audit itself: run it against a pinned historical commit containing a known, since-fixed conformance bug (e.g. `b557385bd`, the commit before the #8322 fix — case-sensitive `X-Sentry-Rate-Limits`/`Retry-After` reads in `DefaultRateLimits.swift`) via `git worktree add`, reading the skill from `main`. It MUST surface that bug as a needs-action mismatch (HIGH or MEDIUM — severity varies between runs; judge on location + failure mode), and a run on current `main` must not report it. Keep validation runs blind: don't tell them which bug to expect or that a fix exists. Last passed: 2026-07-27.

## Running it

- **claude.ai routine (now):** checkout `getsentry/sentry-cocoa` `main`; prompt: _"Run the relay-conformance-audit skill at skills/relay-conformance-audit/SKILL.md and follow it exactly. Post the report to Slack #team-sdk-apple (main message + TLDR and full detail as threaded replies)."_ Weekly cron, e.g. `0 7 * * 3` UTC.
- **CI (later):** a scheduled GitHub Actions workflow invoking Claude Code headlessly with the same one-line prompt; Slack via bot token (`chat.postMessage`, `thread_ts` for replies; always check `.ok`).
- **Maintenance:** `references/findings.md` is edited only by humans via reviewed PRs — filed an issue → add it under Tracked; won't-fix → add under Ignored with an explicit ignore-scenario; fixed or obsolete → remove the entry.
