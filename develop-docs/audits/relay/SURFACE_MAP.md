# Audit surface map — Cocoa ↔ Relay

One section per protocol area. Each = Cocoa files to read · develop-docs to fetch · Relay source to diff · **what to check**. Spawn one subagent per area (parallel). Paths are relative to the sentry-cocoa repo root. Relay's `master` is the source of truth; if a Relay path 404s, search the repo for the named symbol and fix this file by PR.

Relay raw base: `https://raw.githubusercontent.com/getsentry/relay/master/`
Develop-docs base: `https://develop.sentry.dev/sdk/`

> [!NOTE]
> File paths drift as the SDK is refactored. If a listed Cocoa file is missing, search for the named symbol (e.g. `SentryDataCategory`, `SentryEnvelopeItemTypes`) and note the moved path in the report.

---

## 1. HTTP header reads — case-sensitivity (the #8322 class)

- **Cocoa:** `Sources/Sentry/SentryNetworkTracker.m`, `Sources/Sentry/SentryTracePropagation.m`, `Sources/Swift/Networking/DefaultRateLimits.swift`, `Sources/Swift/Core/Tools/URLSessionTaskHelper.swift`, `Sources/Swift/Tools/SentryURLRequestFactory.swift`.
- **Spec:** RFC 9113 §8.2.1 (HTTP/2) and RFC 9114 §4.2 (HTTP/3) — field names are lowercased on the wire; `expected-features/rate-limiting/`.
- **What to check:** every **single-header read**. A subscript on `allHeaderFields[...]` or `allHTTPHeaderFields[...]` is **case-SENSITIVE → unsafe** (server may send lowercased names). `valueForHTTPHeaderField:` / the Swift `value(forHTTPHeaderFieldCaseInsensitive:)` helper is safe. Reading the _whole_ dictionary (iteration) is fine. Flag any unsafe subscript, especially on a **response**.
- Also check the **linters** guarding this: `.swiftlint.yml` (`avoid_all_header_fields`), `scripts/check-objc-banned-pattern.sh`, `Makefile` (`lint`/`lint-staged`), and whether a CI workflow runs the ObjC linter.

## 2. Rate-limit / Retry-After parsing

- **Cocoa:** `Sources/Swift/Networking/RateLimitParser.swift`, `Sources/Swift/Networking/RetryAfterHeaderParser.swift`, `Sources/Swift/Networking/DefaultRateLimits.swift`.
- **Spec:** `expected-features/rate-limiting/`. Relay: `relay-quotas/` (rate-limit format).
- **What to check:** `X-Sentry-Rate-Limits` format `retry_after:categories:scope:reason_code:namespaces`, comma-separated quotas. Must: ignore spaces ("the header may contain spaces which must be ignored"); empty categories field → **all** categories; a limit whose categories are **all unknown** → **ignored** (never applied to `default`); `metric_bucket` namespaces handled; `Retry-After` on a 429 → treat like `categories=[]`; 429 with neither header → 60s all-categories. **Both header reads must be case-insensitive** (the #8324 fix — a regression here is HIGH).

## 3. Data categories

- **Cocoa:** `Sources/Swift/Networking/SentryDataCategory.swift` (enum + wire-name strings), `Sources/Swift/Networking/SentryDataCategory+EnvelopeItemType.swift` (item-type → category mapping).
- **Relay:** `relay-base-schema/src/data_category.rs` — the `DataCategory` enum, its `#[serde(rename)]`/`name()` strings, and numeric discriminants.
- **What to check:** every category **name** Cocoa emits/parses must match Relay's `name()`/`from_name` **exactly** (lowercase). Flag: (a) name mismatch; (b) a category Relay defines that Cocoa maps to `.unknown` (→ silently mishandled rate limits/outcomes) — especially newly-added Relay categories; (c) the `profile_chunk` (item) → `profile_chunk_ui` (category) inference; (d) any place a numeric **index** is put on the wire (must be none — Cocoa's raw values intentionally DIFFER from Relay's discriminants; indices are internal-only). Cross-ref §2: unknown names get dropped in `RateLimitParser.swift`.

## 4. Envelope item types

- **Cocoa:** `Sources/Swift/Helper/SentryEnvelopeItemType.swift` (the `SentryEnvelopeItemTypes` constants), `Sources/Swift/Tools/SentryEnvelopeItem.swift` (item construction, incl. replay msgpack keys `replay_event`/`replay_recording`/`replay_video`), `Sources/Sentry/Profiling/SentryProfilerSerialization.m` (`profile`/`profile_chunk`), `Sources/Swift/Tools/TelemetryProcessor/TelemetryScheduler.swift` (`log`/`trace_metric`).
- **Relay:** `relay-server/src/envelope/item.rs` — `ItemType` enum + `from_str`/serde renames.
- **Spec:** `data-model/envelope-items/`.
- **What to check:** every item-type string Cocoa **emits** must be recognized by Relay's `ItemType::from_str` with exact casing/spelling (e.g. `log`, not `otel_log`). Unrecognized → Relay `ItemType::Unknown` (preserved, but a sign of drift). Flag any Cocoa item type Relay doesn't recognize, and any hardcoded item-type literal that bypasses the `SentryEnvelopeItemTypes` constants.

## 5. Client reports / discard reasons / outcomes

- **Cocoa:** `Sources/Sentry/SentryDiscardReasonMapper.m`, `Sources/Swift/Networking/SentryDiscardReason.swift`, `Sources/Swift/Tools/SentryClientReport.swift`, `Sources/Swift/Tools/SentryDiscardedEvent.swift`, and drop-recording sites (`Sources/Sentry/SentryHttpTransport.m`, `SentryClient.m`, `SentryHub.m`, `SentryTransportAdapter.m`).
- **Spec:** `telemetry/client-reports/` (allowed `reason` values). **Relay:** `relay-event-schema/src/protocol/client_report.rs` (`ClientReport`/`DiscardedEvent` shape), `relay-server/src/processing/client_reports/process.rs` (reason handling), `relay-server/src/services/outcome.rs`.
- **What to check:** every discard **reason** string in the client-report path must be in the develop-docs allowlist — watch spelling (`ratelimit_backoff`, NOT `rate_limit_backoff`). Client-report payload shape must be `{timestamp, discarded_events:[{reason, category, quantity}]}`; SDK must NOT populate Relay-reserved arrays (`rate_limited_events`/`filtered_events`/`filtered_sampling_events`). Verify 429s are **not** double-counted client-side (Relay records them server-side). Verify rate-limit drops attribute to the right category with `ratelimit_backoff`.

## 6. Auth / request format

- **Cocoa:** `Sources/Swift/Tools/SentryURLRequestFactory.swift`, `Sources/Swift/SentryDsn.swift`, `Sources/Swift/Networking/SentryNSURLRequestBuilder.swift`.
- **Spec:** `overview/` (authentication / `X-Sentry-Auth`), `data-model/envelopes/` (envelope endpoint).
- **What to check:** `X-Sentry-Auth: Sentry sentry_version=7,sentry_client=<name>/<ver>,sentry_key=<publicKey>[,sentry_secret=…]`; `sentry_version` value (`7`); `Content-Type: application/x-sentry-envelope`; `Content-Encoding: gzip` (+ body gzipped); `POST`; endpoint path `<dsn-extra-path>/api/<projectId>/envelope/` derived from the DSN. Flag any token/spelling/version divergence.

## 7. Dynamic Sampling Context (baggage)

- **Cocoa:** `Sources/Sentry/SentryBaggage.m` (`toHTTPHeaderWithOriginalBaggage:` — the `sentry-`prefixed keys), `Sources/Sentry/SentryTraceContext.m` (`initWithDict:` un-prefixed keys + `serialize` + the trace-only constructor), `Sources/Swift/Core/Helper/SentryBaggageSerialization.swift`.
- **Spec:** `foundations/trace-propagation/dynamic-sampling-context/`.
- **What to check:** required/optional DSC keys present and exactly named: `trace_id, public_key, release, environment, transaction, sample_rate, sample_rand, sampled, replay_id, org_id`. Specifically check `sample_rand` (required since v1.1.0) and `org_id` (since v1.2.0) are generated/propagated. Flag: missing keys on any DSC path; numeric serialization precision of `sample_rand`/`sample_rate` (rounding can break the `sample_rand < sample_rate ⟺ sampled` invariant); `sentry-sampled` value strings (`true`/`false`).

## 8. sentry-trace header

- **Cocoa:** `Sources/Sentry/SentryTraceHeader.m` (`value`).
- **Spec:** `foundations/trace-propagation/`.
- **What to check:** wire format `traceid-spanid-sampled`; `trace_id` = 32 hex, `span_id` = 16 hex; sampled = `1`/`0`/omitted; header always includes trace+span. Flag divergence.

## 9. Sessions

- **Cocoa:** `Sources/Swift/SentrySession.swift` (model + `serialize`), session-envelope build sites, `Sources/Swift/Helper/SentryMigrateSessionInit.swift`.
- **Spec:** `telemetry/sessions/`.
- **What to check:** payload fields + exact names: `sid, did, init, started, timestamp, status, errors, duration, seq, attrs{release, environment, ip_address, user_agent}`; status values `ok/exited/crashed/abnormal` (no `errored`/`unhandled` as a session status); `init`/`seq` dedup semantics + never-drop-init migration; `duration` omitted on init. Session **aggregates** are optional for a mobile client (Cocoa sends individual sessions — conformant). Flag missing/mis-named fields or wrong status strings.

## 10. Sampling numbers & invariant

- **Cocoa:** `Sources/Sentry/SentrySampling.m` (`_sentry_calcSample`), `Sources/Sentry/SentryTraceContext.m` (serialization of `sample_rand`/`sample_rate`).
- **Spec:** `foundations/trace-propagation/dynamic-sampling-context/` (the `sample_rand < sample_rate ⟺ sampled` invariant).
- **What to check:** decision computed at full precision but transmitted rounded; `<=` vs strict `<` at the boundary; `sample_rand` seeded once at trace start and reused. Flag precision/among-events consistency risks.
