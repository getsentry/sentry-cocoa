# Cocoa ↔ Relay Protocol Conformance Audit

Audits the Sentry Cocoa SDK for **protocol-conformance drift** against **Relay** ([getsentry/relay](https://github.com/getsentry/relay)) — anywhere a string or wire format the SDK must match Relay exactly could silently drop, mis-route, or miscount data.

**Why this exists:** bug [#8322](https://github.com/getsentry/sentry-cocoa/issues/8322) (fixed in [#8324](https://github.com/getsentry/sentry-cocoa/pull/8324)) came from reading the `X-Sentry-Rate-Limits` response header with a _case-sensitive_ lookup — which silently fails over HTTP/2/HTTP/3 (headers are lowercased on the wire), causing the SDK to rate-limit **all** categories and drop telemetry. That is one instance of a general shape: **the SDK hard-codes many strings and wire formats that must match Relay exactly, and a mismatch fails silently.** This audit hunts for that whole class, repeatably.

**This audit is READ-ONLY.** It never edits SDK code, opens PRs, files issues, or modifies `FINDINGS.md`. Its only output is a report (Slack post or printed).

## When to run

- Weekly on a schedule (see `ROUTINE_PROMPT.md`).
- On demand before/after a networking or protocol change.
- After Relay adds a `DataCategory` / `ItemType` / discard reason, to check whether Cocoa needs to learn it.
- In validation mode against the pinned pre-fix commit (see `VALIDATION.md`) whenever this procedure or `SURFACE_MAP.md` changes materially.

## Inputs

- A **sentry-cocoa checkout** on current `main` (or the pinned SHA in validation mode). Record `git rev-parse --short HEAD` and `date +%Y-%m-%d` via shell — both stamp the report. Do not hardcode dates.
- **This folder** (`develop-docs/audits/relay/`) read from the _current `main`_ checkout — in validation mode the audited worktree predates these files.
- **Web access** to fetch Relay source (`raw.githubusercontent.com`) and develop-docs pages (`develop.sentry.dev`).
- **Slack** (scheduled runs): post via the configured Slack connector / bot token per `REPORT_FORMAT.md`.

## Procedure

1. **Snapshot the target.** Ensure the checkout is current; record SHA + date.

2. **Fan out the diff.** For **each area** in `SURFACE_MAP.md`, spawn a read-only subagent (run areas in parallel) with this contract:
   - Fetch the listed develop-docs URL(s) and Relay source file(s).
   - Read the listed Cocoa source files.
   - Diff them against the area's "what to check" notes.
   - Return structured findings, each: `{ area, severity (HIGH|MEDIUM|LOW), location (file + symbol), summary, spec_citation (URL or Relay file), failure_mode }`, plus a short list of what it verified **CONFORMANT**.
   - Cite exact wire strings and symbols. Severity is about **silent blast radius**, not fix effort: a wire-string mismatch that silently drops data is HIGH even if the fix is one line.

3. **Classify against the registry.** Load `FINDINGS.md`. Match each raw finding on its **fingerprint** — `area` + `file` + normalized one-line summary (line numbers drift; never match on them). Label:
   - **NEW** — no matching entry. _The only classification that makes noise._ Assign provisional labels `NEW-1`, `NEW-2`, … (permanent `RELAY-###` IDs are assigned by a human when triaging into `FINDINGS.md`).
   - **KNOWN** — matches an `open` or `accepted` entry. Counted in the delta, not re-detailed. For `accepted` entries, first check the entry's _ignore-scenario_ still holds — if it no longer does, escalate to **NEW**.
   - **REGRESSION** — matches a `fixed` entry (the bug is back), or breaks an item on the conformant checklist. Report as **NEW / HIGH**, prefixed `REGRESSION`.
   - **RESOLVED** — an `open` entry the run no longer reproduces. Report it (suggest flipping to `fixed`), but it is good news, not noise.

4. **Assemble the report** per `REPORT_FORMAT.md`: a skimmable **delta** (counts + NEW/RESOLVED bullets; quiet week = one ✅ line), a **TLDR management summary** thread reply, and a **full agent-pickup report** thread reply. Stamp all with date + SHA.

5. **Deliver.** Scheduled: post to Slack per `REPORT_FORMAT.md`; if the post fails, print everything and state loudly that the Slack post FAILED — never report success on a failed post. Interactive: print delta, then full report.

6. **Never modify SDK code or `FINDINGS.md`.** Registry changes are human decisions via normal PRs (see `FINDINGS.md` header for the maintenance rules).

## Output contract

- The **delta** must be skimmable in 5 seconds: run header (date + SHA), one count line (`NEW n · RESOLVED n · known n · conformant ok/BROKEN`), then NEW/RESOLVED bullets. Quiet weeks are a single ✅ line.
- The **TLDR** is for humans deciding whether to care: 2–4 plain sentences per NEW finding — what's broken, user impact, blast radius. No jargon, no file paths.
- The **full report** is for the agent (or human) who picks the finding up cold: files + symbols, exact wire strings, spec/Relay citations, failure mode, suggested verification steps.
- Prefer precise locations and exact wire strings over prose — this is a diff, not an essay.

## Guardrails

- **Read-only, always.** No `git commit`, no `gh pr`, no issue creation. Issue creation is a human click on the pre-filled link in the report.
- **Relay paths move.** If a Relay source file 404s, search the repo for the symbol (`ItemType`, `DataCategory`, `ClientReport`) rather than trusting a stale path; note the moved path in the report so `SURFACE_MAP.md` can be updated by PR.
- **Bounded cost:** one subagent per area, run in parallel; don't recurse into unrelated SDK subsystems (`SentryCrash/` and other non-protocol code are out of scope unless the surface map names a file there).

## Portability

The procedure above is SDK-agnostic; everything Cocoa-specific lives in `SURFACE_MAP.md` and `FINDINGS.md`. To adopt this audit in another SDK repo (sentry-java, sentry-react-native, …), copy this folder shape and rewrite those two files. Keep the ID namespace per target (`RELAY-###` here; a future develop-docs-spec audit uses `SPEC-###`) so registries never collide.
