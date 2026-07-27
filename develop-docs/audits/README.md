# Protocol Conformance Audits

Recurring, agent-driven audits that diff this SDK's wire protocol against an external source of truth. Each audit target gets its own folder with the same file shape, so the convention can be copied to other SDK repos (sentry-java, sentry-react-native, …).

| Folder   | Compares against                                      | Status  |
| -------- | ----------------------------------------------------- | ------- |
| `relay/` | [getsentry/relay](https://github.com/getsentry/relay) | active  |
| —        | develop-docs SDK spec (develop.sentry.dev/sdk)        | planned |

## Folder shape (per audit target)

| File                | Purpose                                                                  |
| ------------------- | ------------------------------------------------------------------------ |
| `AUDIT.md`          | The audit procedure: how to run, classify, and report                    |
| `SURFACE_MAP.md`    | What to diff: SDK files ↔ external source ↔ spec pages, per area         |
| `FINDINGS.md`       | Deterministic findings registry: open / accepted (ignore list) / fixed   |
| `REPORT_FORMAT.md`  | Slack delta + threaded report templates, one-click GitHub issue links    |
| `VALIDATION.md`     | Self-test: pinned pre-fix commit the audit MUST flag, pass/fail criteria |
| `ROUTINE_PROMPT.md` | The exact scheduler prompt (source of truth for the claude.ai routine)   |

## Principles

- **Read-only** — the audit never edits SDK code, opens PRs, or files issues. Its only output is a report.
- **Low noise** — only NEW findings make noise; a quiet week is a single ✅ line. Everything already triaged lives in `FINDINGS.md` and is counted, not repeated.
- **Deterministic IDs** — findings get stable IDs (`RELAY-###`) assigned only via committed PRs to `FINDINGS.md`. The registry is the memory; the audit matches against it, humans maintain it.
- **Validated** — each audit has a pinned historical commit containing a real, serious bug it must detect (see `VALIDATION.md`). Re-run validation whenever the procedure or surface map changes materially.
