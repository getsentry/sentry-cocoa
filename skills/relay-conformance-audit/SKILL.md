---
name: relay-conformance-audit
description: Audit the Cocoa SDK for protocol-conformance drift against Relay (getsentry/relay) — hard-coded strings/wire formats that must match Relay exactly and fail silently when they don't (the class behind #8322, the case-sensitive rate-limit header). Every candidate mismatch is corroborated against the peer SDKs (sentry-java, -dart, -react-native, -javascript, -python): a Cocoa-only divergence is confirmed with peer code links, an all-SDK agreement is treated as a likely false positive and dropped. Read-only; outputs a report, never fixes code. Use for the scheduled weekly check or on demand after networking/protocol changes.
---

# Cocoa ↔ Relay conformance audit

The SDK hard-codes many strings and wire formats that must match Relay exactly — header names, envelope item types, data categories, discard reasons, DSC keys, session fields. A mismatch anywhere in that surface fails **silently**: data is dropped, mis-routed, or miscounted with no error. This skill audits that entire surface. One motivating example of the class: [#8322](https://github.com/getsentry/sentry-cocoa/issues/8322) (a case-sensitive `X-Sentry-Rate-Limits` header read silently rate-limited all telemetry) — but the skill exists to hunt bugs _like_ it, wherever they occur, not that one bug.

**READ-ONLY toward the SDK.** Never edit SDK code or file issues. Never modify `references/findings.md`. The only outputs are the report and — sole exception — a draft PR the coverage check opens against `getsentry/sentry-cocoa` that touches nothing but `references/surface-map.md` (see "Coverage check"). When the map is out of date, the skill opens that draft PR directly rather than only flagging the gap.

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
4. **Cross-SDK corroboration** (see below): for every mismatch that is still **needs action** after step 3, check how the peer SDKs implement the same wire surface. This is the confidence gate — it strengthens `cocoa-only` findings with exact peer code locations and silently drops `all-sdks-agree` false positives.
5. Build the report (below), appending the coverage-check result, and deliver: post to Slack when a connector is configured, otherwise print. If a Slack post fails, print everything and state loudly the post FAILED — never report success on a failed post.

## Coverage check (surface-map self-audit)

The audit only inspects what the surface map lists, so a stale map is a silent coverage hole. Every run, one extra subagent checks the map itself — from both directions:

- **SDK side:** list protocol-relevant code the map does NOT reference. Grep the SDK for wire-emitting surfaces: `serialize` implementations feeding envelopes, envelope item construction, `setValue(_:forHTTPHeaderField:)` / header reads, files under `Sources/Swift/Networking/` and `Sources/Swift/Protocol/`, new integrations writing envelope items. Compare against the files the map lists; report unlisted ones that put bytes on the wire.
- **Relay side:** for each Relay/spec source the map cites, check it still exists (note moved paths) and skim Relay's protocol enums (`DataCategory`, `ItemType`, discard reasons, DSC keys) for members added since the map's checks were written that no area would catch.
- Ignore non-wire code (`SentryCrash/` internals, UI, tests) — the bar is "could a mismatch here silently corrupt what Relay receives?".

Outcome:

- **Map up to date** → one line in the report: `coverage: OK`.
- **Gaps found** → list them in the report under `coverage: GAPS`, **and directly open a draft PR** against `getsentry/sentry-cocoa` (base `main`) that updates ONLY `references/surface-map.md` — don't just describe it, push it. The map drifts as the SDK changes, so this is the mechanism that keeps it current. Mechanically:
  1. Edit `skills/relay-conformance-audit/references/surface-map.md` only — extend an area's file list, fix a moved Relay path, or add a new area (with **What it is / Cocoa / Relay-Spec / Check**, all links as `blob/main` (Cocoa) or `blob/master` (Relay), matching the file's existing format).
  2. Branch `chore/relay-audit-surface-map-<date>`. Commit just that file: `chore: update relay-audit surface map` with `#skip-changelog` in the body.
  3. Push and `gh pr create --draft --base main --title "chore: update relay-audit surface map"`; body = the gap list + one line per gap on why it belongs in the map + "Opened by relay-conformance-audit coverage check, <DATE>, @<SHA>." Put the resulting PR URL in the report's `coverage` line.
  - This is the skill's **only** permitted write: never touch SDK code, `findings.md`, or `SKILL.md` in that PR; leave it as a draft and never merge — a human reviews. If a draft PR from a previous run is still open, push to that branch and update its body instead of opening a second one. If `gh` isn't authenticated or the push fails, say so loudly in the report and include the diff inline — never report the PR as opened when it wasn't.
- Gaps are NOT mismatches: report them in the coverage section only; the newly-discovered files get audited by the next run after the map PR merges.

## Cross-SDK corroboration

Diffing Cocoa against Relay + develop-docs alone produces false positives: when the develop-docs spec is aspirational/wrong, or Relay tolerates a value, the docs-vs-Relay disagreement gets blamed on Cocoa. The peer SDKs are a second source of truth. If Cocoa is the **only** SDK that diverges, the finding is almost certainly real; if **every** SDK does the same thing Cocoa does, the "mismatch" is almost certainly a misreading of the spec, not a Cocoa bug.

Run this only on mismatches that are still **needs action** after the `findings.md` match (step 3) — never on tracked/ignored entries. That bounds the extra searches to exactly the findings that would be reported.

Peer repos, in priority order (mobile first): `getsentry/sentry-java`, `getsentry/sentry-dart`, `getsentry/sentry-react-native`, then `getsentry/sentry-javascript`, `getsentry/sentry-python`.

**Locate peer code by the wire string, not a file map.** The exact literal the mismatch is about (discard-reason string, header name, envelope item-type, DSC key, session field) is the stable locator — search each repo for it, e.g. `gh search code --repo getsentry/sentry-java "ratelimit_backoff"`. This lands directly on the peer's implementation with no per-SDK map to maintain and keep in sync. If the literal search misses (a repo names the constant differently), fall back to the role-analogous file, then move on — a peer you genuinely can't locate is recorded as not-checked, not as agreement.

**Count only independent implementations.** A peer only corroborates if it implements the audited surface **itself**. When a peer is a wrapper that delegates the surface to another SDK already in the list, its result is inherited, not independent evidence — so record it as `not-checked` and exclude it from the quorum. In practice this is `sentry-react-native`: for native wire surfaces (transport, rate-limit headers, envelope framing) it delegates to the native `sentry-cocoa`/`sentry-java` SDKs, and for JS-level surfaces it reuses `@sentry/core` from `sentry-javascript` — in both cases the underlying implementation is another peer you already check, so counting RN too would let a **single** implementation satisfy the two-peer quorum. RN counts only when it carries its **own** implementation of the specific surface. When unsure whether a peer is independent for a given surface, treat it as `not-checked` — conservative, never inflates the quorum.

For each needs-action mismatch, classify each **independent, located** peer into exactly one of three buckets — **matches Relay** (implements the spec-correct value Cocoa is missing), **matches Cocoa** (shares Cocoa's divergent value), or **matches-neither** (implements a _third_ value/format that is neither Relay's nor Cocoa's). A peer you couldn't locate, or a non-independent wrapper, is `not-checked` and counts toward none of the three. Then set a verdict. The five verdicts are mutually exclusive; evaluate them in this order:

- **`inconclusive`** — fewer than **2** independent peers could be located (mobile SDKs preferred in the count). Corroboration is too thin to trust either way → **report as needs-action** regardless, flagged _"cross-SDK inconclusive — only <n> independent peer(s) located"_. This case takes precedence over the others: never silently drop a finding on weak evidence, because a wire-string search that misses everywhere would otherwise let a real bug vanish. This is the guard against a vacuous `all-sdks-agree`.
- **`ecosystem-divergent`** — ≥2 independent peers located and **at least one is matches-neither** → a third implementation exists, which is itself a signal of spec ambiguity, not Cocoa-specific breakage. **Always report** as needs-action; call out each third value and its peer. A `matches-neither` peer can never be folded into agreement, so this blocks both `cocoa-only` and `all-sdks-agree`. Takes precedence over the three below.
- **`cocoa-only`** — ≥2 independent peers located and **every one matches Relay** (none match Cocoa, none matches-neither) → Cocoa is the sole outlier, finding **confirmed and strengthened**. Report it, flagged higher-confidence, with clickable `blob/`-pinned links to the peer code showing the correct implementation.
- **`mixed`** — ≥2 independent peers located, all classify as either matches-Relay or matches-Cocoa (no matches-neither), and they **split** (at least one each) → report normally; note which peers side with Cocoa and which with Relay. Do not label a split `cocoa-only`.
- **`all-sdks-agree`** — ≥2 independent peers located and **every one matches Cocoa** (none matches Relay, none matches-neither) → strong **false-positive** signal. Before acting, re-read the Relay source directly to confirm what it actually does with the value. Default: **drop the finding silently** — omit it from the report entirely, with no count and no trace. Escape hatch: if after re-reading Relay you are still certain it is a real wire bug affecting all SDKs, report it as needs-action, explicitly labeled _"affects all SDKs — likely a spec/Relay-wide issue, not Cocoa-specific"_ and sorted last. The escape hatch is certainty-gated, so the common case stays silent.

Add the result to each reported mismatch as `crossSDK: { located:[repos], notChecked:[{repo, reason: unlocated|wrapper}], matchRelay:[{sdk, link, note}], matchCocoa:[{sdk, link}], matchNeither:[{sdk, link, value}], verdict: inconclusive|ecosystem-divergent|cocoa-only|mixed|all-sdks-agree }`.

## Report

Main message (Slack mrkdwn — no tables, `*bold*`, `` `code` ``), severity-sorted:

```
:shield: *Cocoa ↔ Relay conformance* — <DATE> · sentry-cocoa@<SHA>
mismatches <n> (<n> need action) · ignored <n> · coverage <OK|GAPS: draft PR link>

:warning: *Needs action* (file the issue or add to the ignore list)
• [HIGH] <area> — <file (symbol)> — <one-line summary> — <create-issue link>
   (append ` · :dart: cocoa-only` when the verdict is cocoa-only — higher confidence; ` · :grey_question: cross-SDK inconclusive` when fewer than 2 independent peers were located; ` · :globe_with_meridians: ecosystem-divergent` when a peer implements a third value)

:ticket: *Tracked*
• #<issue> <area> — <one-line summary>

Rate this report: :thumbsup: findings look accurate · :thumbsdown: something's off. If a finding is wrong or overblown, drop a short reply in the thread saying which one and why.
```

Everything tracked or ignored: `:white_check_mark: Nothing needs action. (tracked <n> · ignored <n>)` — still invite the report-level vote.

Thread reply 1 — **TLDR**: per needs-action mismatch, 2–4 plain sentences for a human deciding whether to care — what broke, user impact, blast radius. No file paths, no jargon.

Thread reply 2 — **full detail**: per needs-action mismatch, everything an agent needs to pick it up cold — location (file + symbol, as a clickable `https://github.com/getsentry/sentry-cocoa/blob/main/<path>` link so a reviewer can jump straight to it), exact wire strings, spec/Relay citation (link it too), failure mode, 1–3 verify steps, and a **Cross-SDK** line: the verdict (`cocoa-only` / `mixed` / `inconclusive` / `ecosystem-divergent`) plus per-peer status — which peers match Relay (with clickable `blob/`-pinned links to their implementation of the correct value), which match Cocoa, which match **neither** (name the third value and link it), and which were `not-checked` (note whether unlocated or excluded as a delegating wrapper). For a `cocoa-only` finding those peer links are the strongest evidence, so lead with them; for `inconclusive`, say plainly how many independent peers were located and why corroboration was thin; for `ecosystem-divergent`, spell out each third value so a human can judge the spec ambiguity. (`all-sdks-agree` findings are dropped and never reach this reply unless the certainty-gated escape hatch fired, in which case carry the _"affects all SDKs"_ label here too.) End with one line noting any tracked/ignored entries that no longer reproduce, and the coverage-check result (gap list + draft-PR link when there are gaps).

Votes and thread replies are feedback for the audit's maintainer only — the audit itself never reads reactions or acts on them; a human follows up and tunes the skill or the ignore list.

Create-issue links: `https://github.com/getsentry/sentry-cocoa/issues/new?title=<urlenc>&body=<urlenc>&labels=Relay-Conformance` — body = the mismatch's full-detail block + "Found by relay-conformance-audit, <DATE>, @<SHA>. After filing: add this issue to skills/relay-conformance-audit/references/findings.md." Keep the URL <8000 chars; trim body to failure mode + Slack-thread pointer if needed.

## Guardrails

- Report only real wire-level mismatches. Style issues, dead code, and things Relay normalizes server-side are ignore-list material, not weekly noise.
- Relay paths move: if a listed path 404s, search the Relay repo for the symbol (`ItemType`, `DataCategory`, `ClientReport`) and audit against the moved file; the coverage check turns the path fix into a draft PR it opens directly.
- Bounded cost: one subagent per area plus one coverage-check subagent; don't recurse into `SentryCrash/` or other non-protocol code. Cross-SDK corroboration adds only wire-string searches against the 5 named peer repos, and only for needs-action mismatches — not every diff.
- Cross-SDK unanimity is a false-positive filter, not a bug detector: when every located peer agrees with Cocoa, default to dropping the finding and re-read Relay directly before ever reporting it. Report an `all-sdks-agree` finding only if you remain certain it's a real wire bug, and label it as affecting all SDKs. Never invert the filter — peer agreement lowers confidence in a finding, it never raises it.
- Unanimity requires a quorum of **independent** implementations: silent-drop (`all-sdks-agree`) is only allowed with **≥2 independently-implemented located peers** all matching Cocoa. Fewer than 2 → `inconclusive` → report as needs-action, never drop. A wire-string search that misses in every repo must never masquerade as agreement — thin evidence surfaces the finding, it doesn't bury it.
- Two things can never feed a silent drop: (1) a wrapper SDK that delegates the audited surface to another checked SDK (e.g. `sentry-react-native` → native cocoa/java, or → `@sentry/core`) — it's `not-checked`, not a second data point; (2) a peer that matches **neither** Relay nor Cocoa — a third value forces `ecosystem-divergent`, always reported. Both guard the same failure: a false `all-sdks-agree` suppressing a genuine mismatch.

## Validation (self-test)

Whenever this skill or the surface map changes materially, validate the audit itself: run it against a pinned historical commit containing a known, since-fixed conformance bug (e.g. `b557385bd`, the commit before the #8322 fix — case-sensitive `X-Sentry-Rate-Limits`/`Retry-After` reads in `DefaultRateLimits.swift`) via `git worktree add`, reading the skill from `main`. It MUST surface that bug as a needs-action mismatch (HIGH or MEDIUM — severity varies between runs; judge on location + failure mode), and a run on current `main` must not report it. The cross-SDK step must return `cocoa-only` for it — the independent peer SDKs (java, dart, javascript, python; `sentry-react-native` is excluded as a wrapper that delegates transport to the native SDKs) read that header case-insensitively (Cocoa was the outlier), which both confirms the finding and exercises the new step end-to-end; a validation run that reports the bug but marks it `all-sdks-agree` (and thus drops it) is a failure. Keep validation runs blind: don't tell them which bug to expect or that a fix exists. Last passed: 2026-07-30 (surfaced the #8322 header bug as HIGH needs-action, verdict `cocoa-only`; absent on current `main`).

## Running it

- **claude.ai routine (now):** checkout `getsentry/sentry-cocoa` `main`; prompt: _"Run the relay-conformance-audit skill at skills/relay-conformance-audit/SKILL.md and follow it exactly. Post the report to Slack #team-sdk-apple (main message + TLDR and full detail as threaded replies)."_ Weekly cron, e.g. `0 7 * * 3` UTC.
- **CI (later):** a scheduled GitHub Actions workflow invoking Claude Code headlessly with the same one-line prompt; Slack via bot token (`chat.postMessage`, `thread_ts` for replies; always check `.ok`).
- **Maintenance:** `references/findings.md` is edited only by humans via reviewed PRs — filed an issue → add it under Tracked; won't-fix → add under Ignored with an explicit ignore-scenario; fixed or obsolete → remove the entry.
