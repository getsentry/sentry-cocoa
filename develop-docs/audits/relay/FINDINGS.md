# Findings registry — Cocoa ↔ Relay

The deterministic memory of the relay conformance audit (see `AUDIT.md`). Every triaged finding lives here with a stable ID. The audit **reads** this file to classify its raw findings; it never writes it. All changes to this file are normal, human-reviewed PRs.

State verified on **2026-07-27** against `main` (post-#8324, post-#8390).

## Rules

- **IDs** are `RELAY-###`, sequential, never reused. Assigning an ID = merging a PR that adds the entry. `legacy` column preserves the IDs from the pre-repo baseline (personal-agent-skills skill, 2026-07-14).
- **Fingerprint** = `area + file + normalized one-line summary`. The audit matches on fingerprints; line numbers are hints only (they drift).
- **Statuses:**
  - `open` — confirmed real, awaiting a fix. Reported weekly as KNOWN (counted, not re-detailed).
  - `accepted` — triaged won't-fix or false positive. **This is the ignore list.** Every `accepted` entry MUST state an _ignore-scenario_: the precise conditions under which it stays ignored. If an audit run finds the scenario no longer holds, the finding escalates to NEW.
  - `fixed` — resolved; kept as a tombstone with the fixing PR. If the audit reproduces a `fixed` finding, that is a **REGRESSION** (NEW / HIGH).
- **Maintenance:** finding fixed in the SDK → flip to `fixed` (never delete — the tombstone is the regression detector). New finding triaged → append with the next free ID. Won't-fix → `accepted` + ignore-scenario.

## Open findings

| ID        | Legacy | Sev    | Area                | Location                                                                  | Summary                                                                                                                                                                                                                 |
| --------- | ------ | ------ | ------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RELAY-004 | F3     | MEDIUM | headers (§1)        | `Sources/Sentry/SentryTracePropagation.m` (`addBaggageHeader`)            | Incoming-baggage read via `allHTTPHeaderFields[SENTRY_BAGGAGE_HEADER]` subscript — case-sensitive; inconsistent with the `valueForHTTPHeaderField:` reads later in the same file.                                       |
| RELAY-005 | G1     | HIGH   | prevention (§1)     | `.github/workflows/`, `Makefile` (`lint`)                                 | ObjC banned-pattern linter (`check-objc-banned-pattern.sh`, rule `avoid_all_header_fields`) runs in `make lint` / pre-commit but **no CI workflow runs it** — only `swiftlint --strict` runs in CI.                     |
| RELAY-006 | G2     | MEDIUM | prevention (§1)     | `Makefile` (`AVOID_ALL_HEADER_FIELDS` pattern), `.swiftlint.yml`          | Banned pattern is `allHeaderFields`, which does not match `allHTTPHeaderFields` — so RELAY-004-shaped bugs slip through the linter.                                                                                     |
| RELAY-007 | G3     | LOW    | prevention (§1)     | `Tests/.swiftlint.yml`                                                    | `parent_config:` doesn't merge parent `custom_rules`; `avoid_all_header_fields` not applied to test code.                                                                                                               |
| RELAY-008 | A      | MEDIUM | DSC (§7)            | `Sources/Sentry/SentryTraceContext.m` + `SentryClient.m` (error path)     | Error-only / no-transaction traces emit a DSC with no `sample_rand`/`sample_rate`/`sampled` (propagation context never seeds `sample_rand`) → Relay must synthesize one; a later transaction in the trace can disagree. |
| RELAY-009 | B      | MEDIUM | DSC (§7, §10)       | `Sources/Sentry/SentryTraceContext.m` (`baggageHttpHeader` serialization) | `sample_rand`/`sample_rate` serialized with `%f` (6-decimal rounding) — can flip Relay's `sample_rand < sample_rate ⟺ sampled` re-derivation at the boundary.                                                           |
| RELAY-017 | L2     | LOW    | client reports (§5) | `Sources/Swift/Networking/SentryDiscardReason.swift` (headerdoc)          | Stale develop-docs link: `/sdk/client-reports/` → moved to `/sdk/telemetry/client-reports/`.                                                                                                                            |

## Accepted findings (the ignore list)

| ID        | Legacy | Sev | Area                 | Location                                                                      | Summary + ignore-scenario                                                                                                                                                                                                                         |
| --------- | ------ | --- | -------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RELAY-010 | C      | LOW | sampling (§10)       | `Sources/Sentry/SentrySampling.m` (`random <= rate`)                          | Spec invariant is strict `<`; Cocoa uses `<=`. **Ignore while:** the only effect is a measure-zero boundary case of a uniform double — negligible in practice.                                                                                    |
| RELAY-011 | 2b     | LOW | data categories (§3) | `Sources/Swift/Networking/SentryDataCategory.swift`                           | Enum raw values diverge from Relay's `DataCategory` discriminants. **Ignore while:** numeric indices never appear on the wire (wire uses names only). If any index is ever serialized → NEW / HIGH.                                               |
| RELAY-012 | 2c     | LOW | data categories (§3) | `Sources/Swift/Networking/SentryDataCategory.swift` + `RateLimitParser.swift` | Unknown rate-limit category names map to `.unknown` and are silently ignored (e.g. non-UI `profile_chunk`). **Ignore while:** Cocoa recognizes every category it emits items for; re-alarm when Relay adds a category matching a Cocoa item type. |
| RELAY-013 | 2e     | LOW | data categories (§3) | `Sources/Swift/Networking/SentryDataCategory+EnvelopeItemType.swift`          | `log` items map only to `log_item`, never `log_byte`, so a `log_byte`-only limit isn't enforced pre-send. **Ignore while:** byte quotas remain a Relay-side concern and other SDKs behave the same.                                               |
| RELAY-014 | D      | LOW | sessions (§9)        | `Sources/Swift/SentrySession.swift` (`_sequence`)                             | `seq` starts at 1 rather than 0/UNIX-ms. **Ignore while:** Relay only requires monotonicity and forces `seq=0` on init server-side.                                                                                                               |
| RELAY-015 | E      | LOW | sessions (§9)        | `Sources/Swift/SentrySession.swift` (`serialize`)                             | `attrs` omitted when release AND environment are both nil, though `attrs.release` is spec-required. **Ignore while:** release is always supplied in practice by `SentryOptions`.                                                                  |
| RELAY-016 | L1     | LOW | client reports (§5)  | `Sources/Sentry/SentryDiscardReasonMapper.m`                                  | `network_error` / `queue_overflow` reason constants defined but no call site records them (dead code). **Ignore while:** both strings remain spec-valid; this is unused code, not a wire mismatch.                                                |

## Fixed findings (tombstones — reproducing any of these is a REGRESSION, NEW / HIGH)

| ID        | Legacy | Area                 | Location                                                             | Summary                                                                                                                                                                                     | Fixed by                                                                                                                            |
| --------- | ------ | -------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| RELAY-001 | —      | rate limits (§1, §2) | `Sources/Swift/Networking/DefaultRateLimits.swift` (`update`)        | `X-Sentry-Rate-Limits` / `Retry-After` read via case-sensitive `allHeaderFields[...]` subscript → nil over HTTP/2/3 → 429 fallback rate-limited **all** categories (silent telemetry loss). | [#8324](https://github.com/getsentry/sentry-cocoa/pull/8324) (issue [#8322](https://github.com/getsentry/sentry-cocoa/issues/8322)) |
| RELAY-002 | F1     | headers (§1)         | `Sources/Sentry/SentryNetworkTracker.m` (response Content-Type read) | Response `Content-Type` read via case-sensitive `allHeaderFields[@"Content-Type"]` subscript. Now uses `SentryHTTPHeaderReader valueForHTTPHeaderFieldCaseInsensitive:`.                    | issue [#8388](https://github.com/getsentry/sentry-cocoa/issues/8388) (closed); verified fixed on `main` 2026-07-27                  |
| RELAY-003 | F2     | headers (§1)         | `Sources/Sentry/SentryNetworkTracker.m` (request Content-Type read)  | Request `Content-Type` read via case-sensitive `allHTTPHeaderFields[...]` subscript. Now uses `NSURLRequest.valueForHTTPHeaderField:` (case-insensitive).                                   | verified fixed on `main` 2026-07-27                                                                                                 |

> [!NOTE]
> **RELAY-001 is the validation target** — see `VALIDATION.md`. A validation run against the pinned pre-fix commit MUST report it as a REGRESSION.

## Conformant checklist (regression detectors)

Verified CONFORMANT on 2026-07-14 (re-confirmed selectively 2026-07-27). If a run finds any of these **broken**, treat it as **NEW / HIGH**, prefixed `REGRESSION`:

- **Envelope item types** — all emitted strings recognized by Relay `ItemType::from_str` with exact casing (`event, transaction, feedback, session, attachment, client_report, profile, profile_chunk, replay_video, log, trace_metric, statsd`); replay msgpack keys `replay_event`/`replay_recording`/`replay_video` match.
- **Data-category names** — all wire names match Relay `name()`/`from_name` (`default, error, session, transaction, attachment, profile, profile_chunk_ui, replay, metric_bucket, span, feedback, log_item, log_byte, trace_metric` + `""` = all); wire uses names, never indices.
- **Discard reasons** — all emitted strings in the develop-docs allowlist; `ratelimit_backoff` correctly spelled (not `rate_limit_backoff`).
- **Client report** — item type `client_report`; payload `{timestamp, discarded_events:[{reason, category, quantity}]}`; Relay-reserved arrays (`rate_limited_events`/`filtered_events`/`filtered_sampling_events`) never populated; 429s not double-counted; rate-limit drops attributed to the correct category with `ratelimit_backoff`.
- **Auth/request** — `X-Sentry-Auth` (`sentry_version=7`, `sentry_client`, `sentry_key`), `Content-Type: application/x-sentry-envelope`, `Content-Encoding: gzip`, `POST`, `/api/<project>/envelope/` path.
- **Rate-limit parser** — strips spaces; empty categories → all; all-unknown-category limits ignored (not applied to `default`); `metric_bucket` namespaces handled; **header-name reads case-insensitive** (the #8324 fix / RELAY-001).
- **DSC keys** — all baggage keys exactly named (`trace_id, public_key, release, environment, transaction, sample_rate, sample_rand, sampled, replay_id, org_id`); `sentry-sampled` = `true`/`false`. (Known gap on the no-transaction path = RELAY-008.)
- **sentry-trace** — `traceid-spanid-sampled`, 32/16 hex, sampled `1`/`0`/omitted.
- **Sessions** — field names + ISO-8601 timestamps + status enum (`ok/exited/crashed/abnormal`) + init/seq dedup + never-drop-init migration.
