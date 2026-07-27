# Scheduled routine prompt — Cocoa ↔ Relay audit

Source of truth for the claude.ai routine that runs the weekly audit. When this file changes, update the routine to match (and re-run `VALIDATION.md`).

## Configuration

- **Schedule:** weekly, e.g. cron `0 7 * * 3` UTC (Wednesdays ~09:00 Europe/Vienna during CEST; cron is fixed UTC, so CET winter = 08:00).
- **Sources (auto-checked-out):** `getsentry/sentry-cocoa` (`main`).
- **Connectors:** Slack (personal account for now; bot token when this migrates to GitHub Actions — see `REPORT_FORMAT.md`).
- **Target channel:** `#team-sdk-apple`.

## Weekly prompt

```
You are running the weekly Sentry Cocoa ↔ Relay protocol-conformance audit. READ-ONLY: never modify SDK code, commit, open PRs, or file issues. Your only external action is posting the report to Slack.

The sentry-cocoa repo (getsentry/sentry-cocoa) is checked out for you on main.

1. Make sure main is current (git pull); record the short commit SHA (git rev-parse --short HEAD) and today's date (date +%Y-%m-%d) via shell — do not hardcode the date.
2. Open develop-docs/audits/relay/AUDIT.md and follow it exactly. Its companion files are in the same folder: SURFACE_MAP.md (what to diff), FINDINGS.md (registry to classify against), REPORT_FORMAT.md (output templates).
3. For each area in SURFACE_MAP.md, spawn a read-only subagent (parallel where available) to diff the mapped Cocoa files against the develop-docs page(s) and Relay source (fetch via raw.githubusercontent.com). Collect structured findings (area, severity, file + symbol, exact wire strings, spec citation, failure mode).
4. Classify each finding NEW / KNOWN / RESOLVED / REGRESSION against FINDINGS.md per AUDIT.md. Only NEW and REGRESSION make noise. Check accepted entries' ignore-scenarios before counting them as KNOWN.
5. Build the three outputs per REPORT_FORMAT.md — delta, TLDR, full agent-pickup report with pre-filled GitHub-issue links — stamped with the date + SHA.
6. Post to Slack #team-sdk-apple: the delta as the main message, then the TLDR and the full report as threaded replies. Verify each Slack response is ok; if the Slack connector is unavailable or a post fails, print everything to your output and state clearly that the Slack post FAILED — do not report success.
```

## Validation prompt (manual trigger)

```
You are running a VALIDATION of the Sentry Cocoa ↔ Relay conformance audit — a self-test of the audit, not a real drift report. READ-ONLY except for creating/removing a temporary git worktree.

The sentry-cocoa repo (getsentry/sentry-cocoa) is checked out for you on main.

1. Open develop-docs/audits/relay/VALIDATION.md and follow it exactly: create a worktree at the pinned pre-fix commit, run the full audit (per develop-docs/audits/relay/AUDIT.md, read from the main checkout) against that worktree, and evaluate the PASS/FAIL criteria.
2. Post the result to Slack #team-sdk-apple prefixed with the validation marker from REPORT_FORMAT.md, ending in VALIDATION PASSED or VALIDATION FAILED. If Slack fails, print everything and state the post FAILED.
3. Remove the worktree when done.
```

## Migration path (later)

1. Once report quality is proven over a few weekly runs, port the weekly prompt into a `.github/workflows/relay-conformance-audit.yml` cron workflow using `anthropics/claude-code-action` (`ANTHROPIC_API_KEY`, `SLACK_BOT_TOKEN`, `SLACK_CHANNEL_ID` as repo secrets; bot-token posting recipe in `REPORT_FORMAT.md`), plus a `workflow_dispatch` input `mode=validate` that runs the validation prompt and fails the job on VALIDATION FAILED.
2. Disable the claude.ai routine so there is exactly one source of truth.
3. The planned develop-docs-spec audit is a **separate** sibling job (`develop-docs/audits/develop-docs-spec/`, ID namespace `SPEC-###`) — never merged into this one.
