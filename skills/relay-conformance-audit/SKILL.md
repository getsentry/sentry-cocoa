---
name: relay-conformance-audit
description: Audit the Cocoa SDK for protocol-conformance drift against Relay (getsentry/relay) — hard-coded strings/wire formats that must match Relay exactly and fail silently when they don't (the class behind #8322, the case-sensitive rate-limit header). Every candidate mismatch is corroborated against the peer SDKs (sentry-java, -dart, -react-native, -javascript, -python): a Cocoa-only divergence is confirmed with peer code links, an all-SDK agreement is treated as a likely false positive and dropped. Never edits SDK code; files/updates `relay-audit:` GitHub issues for each finding. Use for the scheduled weekly check or on demand after networking/protocol changes.
---

# Cocoa ↔ Relay conformance audit

The SDK hard-codes many strings and wire formats that must match Relay exactly — header names, envelope item types, data categories, discard reasons, DSC keys, session fields. A mismatch anywhere in that surface fails **silently**: data is dropped, mis-routed, or miscounted with no error. This skill audits that entire surface. One motivating example of the class: [#8322](https://github.com/getsentry/sentry-cocoa/issues/8322) (a case-sensitive `X-Sentry-Rate-Limits` header read silently rate-limited all telemetry) — but the skill exists to hunt bugs _like_ it, wherever they occur, not that one bug.

**READ-ONLY toward the SDK.** Never edit SDK code. Never modify `references/findings.md` (the human-maintained ignore list). The skill's primary output is **`relay-audit:` GitHub issues** (created or edited — see "GitHub issues"). The one other permitted write is a draft PR the coverage check opens against `getsentry/sentry-cocoa` that touches nothing but `references/surface-map.md` (see "Coverage check"). When the map is out of date, the skill opens that draft PR directly rather than only flagging the gap.

## Model

Every run evaluates the **full current list of mismatches** — no delta tracking, no run-to-run memory. GitHub is the tracker; `references/findings.md` holds only the ignore list. A mismatch is in one of three states:

- **Ignored** — listed in `references/findings.md` with an explicit _ignore-scenario_. Skipped (counted only) while the scenario holds; becomes needs-action when it no longer holds.
- **Needs action** — everything else, unless cross-SDK corroboration drops it. The skill searches GitHub for an existing `relay-audit:` issue matching the mismatch (by fingerprint) and:
  - **open match** → **edits that issue's description** with the latest analysis and refreshed commit-pinned permalinks.
  - **closed match** → a possible regression, but the audit doesn't presume why it was closed: it **comments once** flagging that the finding reproduces again (reopen if regressed, or add to the ignore list if closed as invalid/duplicate) and surfaces it in the console summary — it does **not** auto-reopen or create a duplicate. A human decides.
  - **no match** → **creates a new `relay-audit:` issue**.
- **Cross-SDK false positive** — a needs-action mismatch whose `all-sdks-agree` verdict drops it: no issue and no per-finding detail (which finding / where / why stays out of the output, so a false positive never reads as real). It is counted **only in aggregate** — a bare `dropped all-sdks-agree <n>` in the console summary so a human can see the filter fired, nothing more (see "Cross-SDK corroboration").

Never open a duplicate: a live GitHub search precedes every create. Two symmetric reverse checks (Procedure step 6) back these promises without the audit ever writing: if an open `relay-audit:` issue's mismatch no longer reproduces (6a), it's surfaced for a human to confirm and close; if an ignored `findings.md` entry no longer reproduces (6b), it's surfaced for a human to prune. The audit never closes issues or edits the ignore list itself.

## Procedure

1. Record `git rev-parse HEAD` (full SHA — needed for permalinks), `git rev-parse --short HEAD`, and `date +%Y-%m-%d` via shell (never hardcode); the full SHA builds the code links, the short SHA + date stamp each issue.
2. For each area in `references/surface-map.md`, spawn one read-only subagent (parallel). Contract: fetch the listed Relay source / develop-docs pages, read the listed Cocoa files, diff per the area's notes. Return mismatches as `{area, severity HIGH|MEDIUM|LOW, file + symbol, line range (start–end), exact wire strings, spec citation, failure mode}`. The **line range is required** — it builds the commit-pinned permalink. Severity = silent blast radius, not fix effort. In parallel with these, spawn the coverage-check subagent (see "Coverage check").
3. Classify each mismatch. First check `references/findings.md` on fingerprint (`area + file + normalized summary` — never line numbers, never severity: severity ratings vary between runs, fingerprints are the stable key): if listed and the ignore-scenario still holds → **ignored**, skip. Otherwise → **needs action**.
4. **Cross-SDK corroboration** (see below): for every mismatch that is still **needs action** after step 3, check how the peer SDKs implement the same wire surface. This is the confidence gate — it strengthens `cocoa-only` findings with exact peer code locations and silently drops `all-sdks-agree` false positives.
5. For each mismatch that survives the cross-SDK gate, run the GitHub-issue pipeline (see "GitHub issues"): search for an existing `relay-audit:` issue on fingerprint, then per Dedup step 3 — **open match** → edit its description; **closed match** → comment once (do not reopen/edit/recreate); **no match** → create a new issue.
6. **Reverse checks (no-longer-reproduces).** Two symmetric checks against this run's **raw mismatch set from Procedure step 2** (every mismatch observed — reported, ignored at step 3, and dropped as `all-sdks-agree` at the cross-SDK gate; all still reproduce, only the pipeline's disposition differs — so match on the raw set, not the filed subset; enumerating a subset and forgetting a category is exactly what mis-flags):
   - **6a — open issues.** List all **open** `relay-audit:` issues (`gh issue list --repo getsentry/sentry-cocoa --search "relay-audit: in:title" --state open --limit 1000 --json number,title,body`; `body` is required to reconstruct each issue's fingerprint — `file` lives in the body, so without `--json ...,body` the match can't be built; same pagination guard as dedup — if the result equals the limit, page before trusting it). Any open issue with **no** matching mismatch this run is a no-longer-reproduces candidate: **do not close it** (a run may miss a finding for benign reasons — a moved file, a flaky peer search); list it in the console summary under "no longer reproduces — verify & close". This backs the Model's promise; without it a fixed mismatch's issue would linger forever.
   - **6b — ignore-list entries.** Diff each `references/findings.md` ignored entry's fingerprint against the same raw mismatch set. Any ignored entry with **no** matching mismatch this run no longer reproduces: **do not edit `findings.md`** (read-only toward it); list its fingerprint in the console summary under "ignore-list entries no longer reproducing — verify & prune" so a human prunes it. This backs the Model's promise for the ignore list, symmetric to 6a for issues.
7. Print the console summary (see "Console summary") and append the coverage-check result. If `gh` is unauthenticated or any `gh` call fails, print everything and state loudly that the issue write FAILED — never report success on a failed write.

## Coverage check (surface-map self-audit)

The audit only inspects what the surface map lists, so a stale map is a silent coverage hole. Every run, one extra subagent checks the map itself — from both directions:

- **SDK side:** list protocol-relevant code the map does NOT reference. Grep the SDK for wire-emitting surfaces: `serialize` implementations feeding envelopes, envelope item construction, `setValue(_:forHTTPHeaderField:)` / header reads, files under `Sources/Swift/Networking/` and `Sources/Swift/Protocol/`, new integrations writing envelope items. Compare against the files the map lists; report unlisted ones that put bytes on the wire.
- **Relay side:** for each Relay/spec source the map cites, check it still exists (note moved paths) and skim Relay's protocol enums (`DataCategory`, `ItemType`, discard reasons, DSC keys) for members added since the map's checks were written that no area would catch.
- Ignore non-wire code (`SentryCrash/` internals, UI, tests) — the bar is "could a mismatch here silently corrupt what Relay receives?".

Outcome:

- **Map up to date** → one line in the console summary: `coverage: OK`.
- **Gaps found** → list them in the console summary under `coverage: GAPS`, **and directly open a draft PR** against `getsentry/sentry-cocoa` (base `main`) that updates ONLY `references/surface-map.md` — don't just describe it, push it. The map drifts as the SDK changes, so this is the mechanism that keeps it current. Mechanically:
  1. Edit `skills/relay-conformance-audit/references/surface-map.md` only — extend an area's file list, fix a moved Relay path, or add a new area (with **What it is / Cocoa / Relay-Spec / Check**, all links as `blob/main` (Cocoa) or `blob/master` (Relay), matching the file's existing format).
  2. Branch `chore/relay-audit-surface-map-<date>`. Commit just that file: `chore: update relay-audit surface map` with `#skip-changelog` in the body.
  3. Push and `gh pr create --draft --base main --title "chore: update relay-audit surface map"`; body = the gap list + one line per gap on why it belongs in the map + "Opened by relay-conformance-audit coverage check, <DATE>, @<SHA>." Put the resulting PR URL in the console summary's `coverage` line.
  - This is the skill's **only** permitted repository write (issue creation/editing aside): never touch SDK code, `findings.md`, or `SKILL.md` in that PR; leave it as a draft and never merge — a human reviews. If a draft PR from a previous run is still open, push to that branch and update its body instead of opening a second one. If `gh` isn't authenticated or the push fails, say so loudly in the console summary and include the diff inline — never report the PR as opened when it wasn't.
- Gaps are NOT mismatches: list them in the coverage section only; the newly-discovered files get audited by the next run after the map PR merges.

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
- **`all-sdks-agree`** — ≥2 independent peers located and **every one matches Cocoa** (none matches Relay, none matches-neither) → strong **false-positive** signal. Before acting, re-read the Relay source directly to confirm what it actually does with the value. Default: **drop the finding** — file no issue and emit no per-finding detail; the only trace is the aggregate `dropped all-sdks-agree <n>` counter in the console summary (never the finding's identity). Escape hatch: if after re-reading Relay you are still certain it is a real wire bug affecting all SDKs, report it as needs-action, explicitly labeled _"affects all SDKs — likely a spec/Relay-wide issue, not Cocoa-specific"_ and sorted last; an escape-hatched finding is filed as an issue and is NOT part of the dropped count. The escape hatch is certainty-gated, so the common case stays a silent count.

Add the result to each reported mismatch as `crossSDK: { located:[repos], notChecked:[{repo, reason: unlocated|wrapper}], matchRelay:[{sdk, link, note}], matchCocoa:[{sdk, link}], matchNeither:[{sdk, link, value}], verdict: inconclusive|ecosystem-divergent|cocoa-only|mixed|all-sdks-agree }`. This block feeds the issue body's cross-SDK section.

## GitHub issues

Each needs-action mismatch maps to exactly one `relay-audit:` GitHub issue on `getsentry/sentry-cocoa`: a new issue when none matches, an edit when an **open** issue matches, or a single flag-comment when only a **closed** issue matches (see Dedup step 3 for the three-way branch). **Never open a duplicate; never reopen or edit a closed issue.**

### Dedup (do this before every create)

1. `gh issue list --repo getsentry/sentry-cocoa --search "relay-audit: in:title" --state all --limit 1000 --json number,title,body,state,comments` — search **open and closed** issues; `state` is required to branch open vs closed in step 3, and `comments` is required so the closed-match path can skip re-posting when its last audit comment already flagged this (per-run de-dup — without it the skill can't tell it already commented). The list is scoped to the `relay-audit:` title prefix, so `1000` covers the audit's own issues for the foreseeable future; **if the result ever returns exactly the limit, the cap was hit — paginate (bump `--limit` or page with the Search API) before trusting a "no match", or a duplicate could slip past the 1000th result.**
2. Match the mismatch's fingerprint (`area + file + normalized summary`, never line numbers/severity) against each candidate's title + body. A hit is the same underlying mismatch even if wording or line numbers drifted. If **multiple** issues match the same fingerprint (e.g. both an open and a closed one, or duplicate opens), **prefer an open match** — pick the most-recently-updated open issue and treat the run as an `open` match (edit it); only when there is **no** open match does a closed match drive the closed path. This prevents commenting on a closed duplicate while an open issue for the same finding goes stale. Note any extra same-fingerprint duplicates in the console summary so a human can consolidate them.
3. **Match found** → branch on the **winning** match's `state` (open preferred, per step 2 — a closed match is used only when no open one exists):
   - **open** → `gh issue edit <number> --body-file <tmp>` with the freshly rebuilt body (new full SHA, refreshed permalinks and detail). Don't change the title unless the area/summary genuinely changed.
   - **closed** → a closed issue whose finding still reproduces is a **possible regression**, but the audit must not presume _why_ a human closed it (fixed-and-regressed vs. closed as invalid/duplicate/won't-fix-without-ignore-entry). So **do not reopen it automatically** — that would fight a human's decision and churn the tracker on every run. Instead **surface it for a human**: post one `gh issue comment <number>` carrying a **stable marker line** `<!-- relay-audit:reproduces-on-closed -->` followed by _"This finding reproduces again as of `<SHORT_SHA>` (<DATE>). If it regressed, reopen; if this issue was closed as invalid/duplicate, add it to the ignore list so the audit stops resurfacing it. — relay-conformance-audit"_ — and list it in the console summary under `closed but still reproduces — reopen or ignore: #<n>`. Comment **at most once per issue**: from the `comments` fetched in step 1, skip posting if any existing comment already contains the `<!-- relay-audit:reproduces-on-closed -->` marker (match on that fixed marker, NOT the comment text — the `<SHORT_SHA>`/`<DATE>` differ every run, so a text compare would never dedup and would re-comment forever). The **console-summary line is unconditional** — list every closed match that reproduced this run whether the comment was posted or skipped-as-duplicate, so the standing signal survives past the one-time comment. Do not create a new issue (that would duplicate the closed one), do not edit the closed issue's body, do not reopen.
4. **No match** → create in **two steps**, because the ignore prompt needs the issue's own number (a chicken-and-egg the placeholder can't resolve at create time):
   a. `gh issue create --title … --label relay-audit --body-file <tmp>` with the body carrying the literal placeholder `#<ISSUE_NUMBER>`. Capture the new issue number from the command's output URL.
   b. `sed`-substitute the real number for **every** `<ISSUE_NUMBER>` in the body, then `gh issue edit <number> --body-file <tmp>`. Verify zero `<ISSUE_NUMBER>` placeholders remain — an unresolved placeholder leaves the one-click ignore prompt pointing at issue `#<ISSUE_NUMBER>` (non-functional).

### Title

`relay-audit: <area> — <one-line summary>` — the `relay-audit:` prefix is **mandatory** on every issue.

### Labels

`relay-audit` (lowercase). If the label doesn't exist yet, create it first (`gh label create relay-audit --description "Cocoa ↔ Relay wire-format conformance audit" --color BFD4F2`), then pass `--label relay-audit` on create.

### Body (identical shape for create and edit)

First an **automated-origin banner** (a blockquote — so anyone landing on the issue immediately knows a bot filed it and how), then a short human intro that **links the exact code inline**, then the full agent-pickup analysis inside a collapsed `<details>` block. Permalinks use the **full SHA** recorded in step 1 of the Procedure so they pin to the audited commit and stay clickable:

The body below is shown in a tilde-fenced (`~~~`) example so the inner triple-backtick prompt block nests cleanly — the issue itself uses normal triple-backtick fences.

````markdown
> 🤖 Automated issue from the [`relay-conformance-audit`](https://github.com/getsentry/sentry-cocoa/blob/<FULL_SHA>/skills/relay-conformance-audit/SKILL.md) skill — weekly bot audit, not hand-filed. Run <DATE> @ `<SHORT_SHA>`. False positive? Use the 🔕 prompt below.

---

<1–3 plain sentences for a human deciding whether to care: what silently breaks, user impact, blast radius. Keep it jargon-free, BUT anchor each claim to the exact code with an inline commit-pinned permalink — e.g. "the SDK rounds the value before sending it ([`SentryTraceContext.m#L108`](https://github.com/getsentry/sentry-cocoa/blob/<FULL_SHA>/<path>#L108))". A human should be able to click straight to the offending line from the intro, not only from the details block.>

**Proof of the correct way (peer SDK):** <always present this line; never omit it. For `mixed`/`cocoa-only`, link a Relay-matching peer; for `ecosystem-divergent`, link a third-value peer — an inline `blob/`-pinned link to the exact peer line, e.g. sentry-java at [`Baggage.java#L41`](https://github.com/getsentry/sentry-java/blob/<peer-sha>/...#L41). For the two verdicts with no peer to cite, state why instead of linking: `inconclusive` → "Proof: none — fewer than 2 independent peers located; evidence thin"; escape-hatched `all-sdks-agree` → "Proof: none — every peer matches Cocoa; escalated as a likely spec/Relay-wide issue" plus a link to the Relay source you re-read.> Cross-SDK verdict: <verdict + one-clause summary>.

**Severity:** HIGH|MEDIUM|LOW · **Area:** <area>

<details>
<summary>Full analysis (for an agent to pick up)</summary>

**Location:** [`<path> (<symbol>)`](https://github.com/getsentry/sentry-cocoa/blob/<FULL_SHA>/<path>#L<start>-L<end>)
**Wire strings:** <exact strings, casings, edge cases>
**Spec / Relay citation:** [<source>](link)
**Failure mode:** <how it silently drops / mis-routes / miscounts>
**Cross-SDK:** verdict (`cocoa-only` / `mixed` / `inconclusive` / `ecosystem-divergent`) + per-peer status — which peers match Relay (clickable `blob/`-pinned links to their correct implementation), which match Cocoa, which match **neither** (name the third value + link), which were `not-checked` (unlocated or excluded wrapper). Lead with the Relay-matching peer links for `cocoa-only`; for `inconclusive` say how many independent peers were located and why evidence was thin; for `ecosystem-divergent` spell out each third value.
**Verify steps:**

1. …

_Found by relay-conformance-audit, <DATE>, @<SHORT_SHA>._

</details>

---

<details>
<summary>🔕 False positive or won't-fix? Add it to the ignore list</summary>

If this finding shouldn't be reported again, add it to the audit's ignore list. From a `getsentry/sentry-cocoa` checkout, copy the prompt below into Claude Code — it will ask you _why_ it should be ignored, then open the PR:

```text
Add relay-audit issue #<ISSUE_NUMBER> to the relay-conformance-audit ignore list.
Read https://github.com/getsentry/sentry-cocoa/issues/<ISSUE_NUMBER>, then follow the
"Adding to the ignore list" section of skills/relay-conformance-audit/SKILL.md: ask me for
the ignore-scenario, append the entry to
skills/relay-conformance-audit/references/findings.md preserving the full fingerprint
context (area | location | summary), and open a short PR against main referencing
#<ISSUE_NUMBER> with #skip-changelog in the body.
```

</details>
````

- The **automated-origin banner is the first thing in the body** — one short `>` blockquote line: bot-filed, links the skill source, stamps date + audited SHA. Keep it terse (one line); substitute `<FULL_SHA>`/`<DATE>`/`<SHORT_SHA>`. Never bury it in the `<details>` footer.
- The intro carries a **"Proof of the correct way"** line linking a peer repo that implements the surface correctly (or, for `ecosystem-divergent`, the peer with a third value) — an inline `blob/`-pinned link to the exact peer line, so a reviewer sees the evidence without opening the details block. This comes straight from the cross-SDK `crossSDK.matchRelay` (or `matchNeither`) result. Two verdicts have no such peer and must instead state why: `inconclusive` (no peer located — already flagged thin-evidence) and an escape-hatched `all-sdks-agree` (every peer matches Cocoa, so there is nothing to cite — write "Proof: none — every peer matches Cocoa; escalated as likely spec/Relay-wide" and link the re-read Relay source).
- The 🔕 ignore prompt lives in its **own collapsible `<details>` block** at the end of the body (summary `🔕 False positive or won't-fix? Add it to the ignore list`) so it doesn't clutter the issue. The prompt block inside uses `` ```text `` so it copies cleanly. It hard-codes the issue's own number, which you only know **after** `gh issue create` — so a fresh create is always the two-step create-then-edit of the Dedup section (create with the `#<ISSUE_NUMBER>` placeholder, then `sed` the real number in and `gh issue edit`); on an edit of an existing issue you already know the number. Verify no `<ISSUE_NUMBER>` placeholder survives. The prompt points at the "Adding to the ignore list" section rather than inlining steps, so the issue text and the procedure never drift.
- **Both** the human intro and the `<details>` block carry commit-pinned code links — the intro links the specific offending line(s) inline in prose; the details block adds the full `Location` list. Never leave the intro link-free and push all links into the details.
- One `Location` link per relevant file; always a commit-pinned line range (`#L<start>-L<end>`), never `blob/main`.
- When editing an existing issue, rebuild the whole body from the current run (fresh SHA + line ranges) — including the ignore prompt with the correct number. Preserve the intro's intent, but the analysis and links always reflect the latest run.
- `all-sdks-agree` findings are dropped at the cross-SDK gate and never reach an issue, unless the certainty-gated escape hatch fired — then carry the _"affects all SDKs"_ label in the intro. For `cocoa-only` / `inconclusive` / `ecosystem-divergent`, add the matching marker to the intro (`cocoa-only — higher confidence`, `cross-SDK inconclusive — only <n> independent peer(s) located`, or `ecosystem-divergent — a peer implements a third value`).

### Console summary

After the issue pipeline, print a severity-sorted summary:

- per filed finding, one line `[SEV] <area> — <summary> — <verdict> — <created|edited> <issue URL>`;
- `closed but still reproduces — reopen or ignore: #<n>, #<n>` — **every** closed match whose finding reproduced this run (from Dedup step 3), regardless of whether a comment was posted or skipped-as-duplicate this run; for a human to reopen or add to the ignore list. This is the standing signal, so it must not disappear after the one-time comment; omit only when there are genuinely none this run;
- `ignore-list entries no longer reproducing — verify & prune: <fingerprint(s)>` — `references/findings.md` entries with no matching mismatch this run (from Procedure step 6b), for a human to prune; omit if none;
- `skipped-ignored <n>` (matched the ignore list);
- `dropped all-sdks-agree <n>` — **aggregate count only**, never the identity of the dropped findings (they are judged false positives; naming them would make a false positive read as real);
- `no longer reproduces — verify & close: #<n>, #<n>` — open `relay-audit:` issues with no matching finding this run (from Procedure step 6), for a human to confirm and close; omit the line if none;
- `coverage:` line (OK, or GAPS + draft-PR link).

Nothing needs action → say so, still print the closed-still-reproduces line, the ignore-prune line, the drop count, the reverse-check line, and the coverage line (any of these can be non-empty even when nothing was filed).

## Adding to the ignore list

This section is driven by the copy-paste prompt embedded in each issue (see "Body"): a maintainer who decides a finding is a false positive or won't-fix pastes that prompt into Claude Code, which then runs these steps. This is **not** part of an audit run — it's a separate, human-initiated action on a single issue.

1. Read the referenced `relay-audit:` issue. From its `<details>` block extract the **area**, **location** (file + symbol), and the normalized one-line **summary** — that triple is the fingerprint the audit matches on.
2. **Ask the user for the ignore-scenario** — the explicit condition under which the finding stays ignored (e.g. _"only a measure-zero boundary of a uniform double"_, _"the index never appears on the wire"_). Use `AskUserQuestion`. Do **not** proceed on a bare "ignore this": without a scenario the audit can't tell when the mismatch matters again, and the entry would silence a future real regression. Never write a placeholder scenario.
3. If the user's answer reveals the finding is actually a **real bug to fix** (not something to ignore), stop — say so and do not touch the ignore list. The ignore list is for accepted/normalized-server-side mismatches, not open bugs.
4. Append one row to the `## Ignored` table of `references/findings.md`, preserving the fingerprint verbatim so future runs skip it:
   `| <area> | <location> | <summary>. **Ignore while:** <user's scenario>. (relay-audit #<ISSUE_NUMBER>) |`
5. Open a PR against `main` from branch `relay-audit/ignore-<ISSUE_NUMBER>`:
   - title `chore: ignore relay-audit finding #<ISSUE_NUMBER>`
   - body: 1–2 sentences — _"Adds finding #<ISSUE_NUMBER> to the relay-conformance-audit ignore list so it's no longer reported. Full fingerprint context is retained so the audit keeps matching it. Refs #<ISSUE_NUMBER>."_ — then `#skip-changelog` on its own line.
   - **Touch only `references/findings.md`.** Never edit SDK code, `SKILL.md`, or `surface-map.md` in this PR. Leave it for human review; do not merge.

## Guardrails

- File issues only for real wire-level mismatches. Style issues, dead code, and things Relay normalizes server-side are ignore-list material, not issues.
- Never open a duplicate. Mandatory on every created or edited issue: the `relay-audit:` title prefix; the leading 🤖 automated-origin banner; the human intro **with inline commit-pinned code links** and a **"Proof of the correct way" peer-repo link** (except `inconclusive` and escape-hatched `all-sdks-agree`, which instead state why no peer can be cited); the collapsed `<details>` analysis (also commit-pinned); and the trailing 🔕 copy-paste ignore prompt in its own collapsible `<details>` block, with the real issue number substituted.
- The ignore prompt must always ask the user for a real ignore-scenario before writing to `findings.md`, and its PR must touch only `findings.md` — never SDK code or the skill files.
- Relay paths move: if a listed path 404s, search the Relay repo for the symbol (`ItemType`, `DataCategory`, `ClientReport`) and audit against the moved file; the coverage check turns the path fix into a draft PR it opens directly.
- Bounded cost: one subagent per area plus one coverage-check subagent; don't recurse into `SentryCrash/` or other non-protocol code. Cross-SDK corroboration adds only wire-string searches against the 5 named peer repos, and only for needs-action mismatches — not every diff.
- Cross-SDK unanimity is a false-positive filter, not a bug detector: when every located peer agrees with Cocoa, default to dropping the finding and re-read Relay directly before ever reporting it. Report an `all-sdks-agree` finding only if you remain certain it's a real wire bug, and label it as affecting all SDKs. Never invert the filter — peer agreement lowers confidence in a finding, it never raises it.
- Unanimity requires a quorum of **independent** implementations: silent-drop (`all-sdks-agree`) is only allowed with **≥2 independently-implemented located peers** all matching Cocoa. Fewer than 2 → `inconclusive` → report as needs-action, never drop. A wire-string search that misses in every repo must never masquerade as agreement — thin evidence surfaces the finding, it doesn't bury it.
- Two things can never feed a silent drop: (1) a wrapper SDK that delegates the audited surface to another checked SDK (e.g. `sentry-react-native` → native cocoa/java, or → `@sentry/core`) — it's `not-checked`, not a second data point; (2) a peer that matches **neither** Relay nor Cocoa — a third value forces `ecosystem-divergent`, always reported. Both guard the same failure: a false `all-sdks-agree` suppressing a genuine mismatch.

## Validation (self-test)

**A validation run MUST NOT create, edit, close, or otherwise write any GitHub issue** (no `gh issue create` / `gh issue edit` / `gh issue comment`, no `gh label create`, no draft PR). Validation is a **local, dry run only**: it builds the finding list in memory and **prints the report to the terminal**, describing what the issue pipeline _would_ do (create vs. edit, which issue number it would match) without executing it. This is a hard rule — a validation run that touches the real `getsentry/sentry-cocoa` tracker is itself a failure, regardless of what it found. If you cannot run it without writing, do not run it.

Whenever this skill or the surface map changes materially, validate the audit itself: run it against a pinned historical commit containing a known, since-fixed conformance bug (e.g. `b557385bd`, the commit before the #8322 fix — case-sensitive `X-Sentry-Rate-Limits`/`Retry-After` reads in `DefaultRateLimits.swift`) via `git worktree add`, reading the skill from `main`. It MUST surface that bug as a needs-action mismatch (HIGH or MEDIUM — severity varies between runs; judge on location + failure mode) and report — in the printed local report — that it _would_ create (or edit an existing match) a `relay-audit:` issue for it, and a run on current `main` must not. The cross-SDK step must return `cocoa-only` for it — the independent peer SDKs (java, dart, javascript, python; `sentry-react-native` is excluded as a wrapper that delegates transport to the native SDKs) read that header case-insensitively (Cocoa was the outlier), which both confirms the finding and exercises the step end-to-end; a validation run that reports the bug but marks it `all-sdks-agree` (and thus drops it) is a failure. Keep validation runs blind: don't tell them which bug to expect or that a fix exists. Last passed: 2026-07-30 (surfaced the #8322 header bug as HIGH needs-action, verdict `cocoa-only`; absent on current `main`).

## Running it

- **claude.ai routine (now):** checkout `getsentry/sentry-cocoa` `main`; prompt: _"Run the relay-conformance-audit skill at skills/relay-conformance-audit/SKILL.md and follow it exactly. File or update `relay-audit:` GitHub issues for each needs-action finding, and print the console summary."_ Weekly cron, e.g. `0 7 * * 3` UTC. Requires an authenticated `gh` with issue write access.
- **CI (later):** a scheduled GitHub Actions workflow invoking Claude Code headlessly with the same one-line prompt; GitHub issue writes via `gh` authenticated with `GITHUB_TOKEN` (needs `issues: write`).
- **Maintenance:** `references/findings.md` is the ignore list, edited only by humans via reviewed PRs — won't-fix → add under Ignored with an explicit ignore-scenario; no longer ignored → remove the entry. Tracking lives in GitHub: close the `relay-audit:` issue when the mismatch is fixed.
