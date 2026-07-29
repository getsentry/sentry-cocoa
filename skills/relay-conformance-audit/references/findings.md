# Findings — tracked & ignored

The audit only reads this file; humans edit it via reviewed PRs. Two lists:

- **Tracked** — mismatches with an existing GitHub issue. The audit reports them with the issue link; no action needed.
- **Ignored** — accepted mismatches. Each entry MUST state an **ignore-scenario**: the conditions under which it stays ignored. The audit omits these (counts only) while the scenario holds; if it no longer holds, the mismatch is reported as needs-action.

Match on fingerprint = area + file + normalized summary (line numbers drift). Everything not in this file that the audit finds is **needs action** and appears in every report until it's fixed, tracked here with an issue, or ignored here with a scenario.

## Tracked (GitHub issue exists)

| Issue | Area | Location | Summary  |
| ----- | ---- | -------- | -------- |
| —     |      |          | none yet |

## Ignored

| Area               | Location                                             | Summary + ignore-scenario                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| sampling §10       | `SentrySampling.m` (`random <= rate`)                | Spec is strict `<`. **Ignore while:** only effect is a measure-zero boundary of a uniform double.                                                                                                                                                       |
| data categories §3 | `SentryDataCategory.swift`                           | Raw values diverge from Relay discriminants. **Ignore while:** indices never appear on the wire (names only); if one is ever serialized, that's HIGH.                                                                                                   |
| data categories §3 | `SentryDataCategory.swift` + `RateLimitParser.swift` | Unknown category names → `.unknown`, silently ignored (server/backend-only categories like `monitor`, `seer_*`). **Ignore while:** Cocoa recognizes every category it emits items for.                                                                  |
| data categories §3 | `SentryDataCategory+EnvelopeItemType.swift`          | `log` maps only to `log_item`, never `log_byte`. **Ignore while:** byte quotas stay Relay-side and other SDKs behave the same.                                                                                                                          |
| sessions §9        | `SentrySession.swift` (`_sequence`)                  | `seq` starts at 1, not 0/UNIX-ms. **Ignore while:** Relay only needs monotonicity and forces `seq=0` on init.                                                                                                                                           |
| sessions §9        | `SentrySession.swift` (`serialize`)                  | `attrs` omitted when release AND environment nil, though `attrs.release` is required. **Ignore while:** release is always supplied by `SentryOptions`.                                                                                                  |
| sessions §9        | `SentrySession.swift` (`serialize`)                  | `attrs.ip_address`/`user_agent` never serialized; `sid` uppercase-dashed; crashed sessions may carry `errors=0`. **Ignore while:** all optional/normalized server-side (Relay auto-fills ip, parses UUID case-insensitively, forces errors≥1 on crash). |
| client reports §5  | `SentryDiscardReasonMapper.m`                        | `network_error`/`queue_overflow` constants defined but never recorded. **Ignore while:** both strings stay spec-valid; unused code, not a wire mismatch.                                                                                                |
| client reports §5  | `SentryDiscardReason.swift` (headerdoc)              | Stale docs link `/sdk/client-reports/`. **Ignore while:** docs-comment only; nothing on the wire.                                                                                                                                                       |
