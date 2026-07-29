# Surface map

The audit hunts one class of bug: a string or wire format the SDK hard-codes that must match Relay **exactly**, where a mismatch fails silently (data dropped, mis-routed, or miscounted with no error). This file is the checklist of where those strings live. One subagent takes one section.

## How to read a section

Each section has three fields:

- **What it is** — plain-language: what bytes the SDK puts on the wire here, and why a mismatch bites.
- **Cocoa** — the SDK files that emit or parse those bytes (clickable, tracking `main`). This is what the SDK _does_.
- **Relay / Spec** — the source of truth to diff against: Relay source (the code that receives the bytes) and/or develop-docs (the written protocol). This is what the SDK _should_ do.
- **Check** — the precise, machine-facing diff to run: the exact strings, casings, and edge cases to compare. Terse on purpose — it's the subagent's checklist, not prose.

Links track `main` (Cocoa) / `master` (Relay). If a linked path 404s, the file moved: search the repo for the named symbol, audit the moved file, and note the move in the report (the coverage check turns a moved path into a draft PR).

---

## 1. HTTP header reads — case-sensitivity

**What it is:** The SDK reads individual HTTP response/request headers by name. Over HTTP/2 and HTTP/3 the wire field names are always lowercase, so a case-sensitive lookup for a capitalized name silently returns nil — the SDK behaves as if the header were absent. This is the exact class behind [#8322](https://github.com/getsentry/sentry-cocoa/issues/8322).

**Cocoa:**

- [`Sources/Sentry/SentryNetworkTracker.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryNetworkTracker.m)
- [`Sources/Sentry/SentryTracePropagation.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryTracePropagation.m)
- [`Sources/Swift/Networking/DefaultRateLimits.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Networking/DefaultRateLimits.swift)
- [`Sources/Swift/Core/Tools/URLSessionTaskHelper.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Core/Tools/URLSessionTaskHelper.swift)
- [`Sources/Swift/Tools/SentryURLRequestFactory.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Tools/SentryURLRequestFactory.swift)

**Spec:** RFC [9113 §8.2.1](https://www.rfc-editor.org/rfc/rfc9113#section-8.2.1) (HTTP/2) / RFC [9114 §4.2](https://www.rfc-editor.org/rfc/rfc9114#section-4.2) (HTTP/3) — field names are lowercase on the wire.

**Check:** every single-header read. `allHeaderFields[...]` / `allHTTPHeaderFields[...]` subscripts are case-SENSITIVE → unsafe (especially on a response). `valueForHTTPHeaderField:` / `value(forHTTPHeaderFieldCaseInsensitive:)` are safe. Whole-dictionary iteration is fine. Also check the guards: [`.swiftlint.yml`](https://github.com/getsentry/sentry-cocoa/blob/main/.swiftlint.yml) `avoid_all_header_fields`, [`scripts/check-objc-banned-pattern.sh`](https://github.com/getsentry/sentry-cocoa/blob/main/scripts/check-objc-banned-pattern.sh), whether any CI workflow runs the ObjC linter.

## 2. Rate-limit / Retry-After parsing

**What it is:** When Relay rate-limits the SDK it replies with an `X-Sentry-Rate-Limits` header (or a `429` + `Retry-After`). The SDK parses that header to decide which data categories to back off and for how long. A parse mismatch either drops nothing when it should back off, or backs off everything when it shouldn't.

**Cocoa:**

- [`Sources/Swift/Networking/RateLimitParser.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Networking/RateLimitParser.swift)
- [`Sources/Swift/Networking/RetryAfterHeaderParser.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Networking/RetryAfterHeaderParser.swift)
- [`Sources/Swift/Networking/DefaultRateLimits.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Networking/DefaultRateLimits.swift)

**Relay / Spec:** [develop-docs: rate limiting](https://develop.sentry.dev/sdk/expected-features/rate-limiting/); Relay [`relay-quotas/`](https://github.com/getsentry/relay/tree/master/relay-quotas).

**Check:** `X-Sentry-Rate-Limits` format `retry_after:categories:scope:reason_code:namespaces`, comma-separated. Ignore spaces; empty categories → all; all-unknown categories → limit ignored (never applied to `default`); `metric_bucket` namespaces; 429 + `Retry-After` → all categories; 429 bare → 60s all. Both header reads must be case-insensitive (HTTP/2/3 lowercase field names on the wire; a case-sensitive miss silently drops the header — HIGH).

## 3. Data categories

**What it is:** Every telemetry item belongs to a data category (`error`, `transaction`, `profile`, …). The SDK emits these names in rate-limit matching and client reports; Relay counts and quota-limits by them. A wrong or missing name means the SDK and Relay disagree about what was sent or dropped.

**Cocoa:**

- [`Sources/Swift/Networking/SentryDataCategory.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Networking/SentryDataCategory.swift)
- [`Sources/Swift/Networking/SentryDataCategory+EnvelopeItemType.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Networking/SentryDataCategory+EnvelopeItemType.swift)

**Relay:** [`relay-base-schema/src/data_category.rs`](https://github.com/getsentry/relay/blob/master/relay-base-schema/src/data_category.rs) (`DataCategory` names + discriminants).

**Check:** every name Cocoa emits/parses matches Relay `name()`/`from_name` exactly (lowercase). Flag: name mismatch; Relay categories Cocoa maps to `.unknown` (esp. newly added); the `profile_chunk` item → `profile_chunk_ui` category inference; any numeric index on the wire (must be none — raw values intentionally differ from Relay's).

## 4. Envelope item types

**What it is:** An envelope is a container of items; each item's header carries a `type` string (`event`, `transaction`, `log`, …) that tells Relay how to route and process it. An unrecognized or mis-cased type means Relay silently drops or misroutes the item.

**Cocoa:**

- [`Sources/Swift/Helper/SentryEnvelopeItemType.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Helper/SentryEnvelopeItemType.swift)
- [`Sources/Swift/Tools/SentryEnvelopeItem.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Tools/SentryEnvelopeItem.swift) (incl. replay msgpack keys)
- [`Sources/Sentry/Profiling/SentryProfilerSerialization.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/Profiling/SentryProfilerSerialization.m)
- [`Sources/Swift/Tools/TelemetryProcessor/TelemetryScheduler.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Tools/TelemetryProcessor/TelemetryScheduler.swift)

**Relay / Spec:** [`relay-server/src/envelope/item.rs`](https://github.com/getsentry/relay/blob/master/relay-server/src/envelope/item.rs) (`ItemType::from_str`); [develop-docs: envelope items](https://develop.sentry.dev/sdk/data-model/envelope-items/).

**Check:** every emitted item-type string recognized by `ItemType::from_str` with exact casing (`log`, not `otel_log`). Flag unrecognized types and literals bypassing the `SentryEnvelopeItemTypes` constants. Item-header `content_type` strings (`application/vnd.sentry.items.log+json`, `application/vnd.sentry.items.trace-metric+json` in `TelemetryScheduler.swift`) must match what Relay routes on.

## 4b. Envelope headers & attachment types

**What it is:** Beyond item types, the envelope header and each item header carry their own fixed keys (`event_id`, `sent_at`, `content_type`, …) and attachments carry an `attachment_type`. Relay reads these to correct clock drift, count items, and decide how to treat each attachment; a renamed key or unknown attachment type is silently ignored.

**Cocoa:**

- [`Sources/Swift/Helper/SentrySerializationSwift.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Helper/SentrySerializationSwift.swift) (envelope header write/parse)
- [`Sources/Swift/Tools/SentryEnvelopeHeader.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Tools/SentryEnvelopeHeader.swift)
- [`Sources/Sentry/SentryEnvelopeItemHeader.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryEnvelopeItemHeader.m) (keys `type, length, content_type, filename, platform, item_count`)
- [`Sources/Sentry/SentryEnvelopeAttachmentHeader.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryEnvelopeAttachmentHeader.m) + [`Sources/Sentry/SentryAttachment.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryAttachment.m) (`attachment_type` values)

**Relay / Spec:** [`relay-server/src/envelope/item.rs`](https://github.com/getsentry/relay/blob/master/relay-server/src/envelope/item.rs) (`AttachmentType` enum, item-header parsing); [develop-docs: envelopes](https://develop.sentry.dev/sdk/data-model/envelopes/), [envelope items](https://develop.sentry.dev/sdk/data-model/envelope-items/).

**Check:** envelope-header keys exactly `event_id, sdk, trace, sent_at` (`sent_at` drives clock-drift correction; `trace` wraps the DSC from §7); item-header key names exact (`item_count`, `content_type`); every emitted `attachment_type` value in Relay's `AttachmentType` enum (`event.attachment`, `event.view_hierarchy`, …) — an unknown value changes how Relay treats the attachment.

## 4c. Log / metric item payloads & attributes

**What it is:** Logs and metrics ship as structured payloads whose field names and attribute `type` strings Relay parses positionally. Area 4 only checks the item-_type_ string on the header; this checks the _contents_. A drift here silently mis-types every log/metric attribute Relay ingests — the item is accepted but its data is wrong.

**Cocoa:**

- [`Sources/Swift/Protocol/SentryLog.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Protocol/SentryLog.swift) (keys `trace_id, span_id, severity_number, body, level`)
- [`Sources/Swift/Protocol/SentryMetric.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Protocol/SentryMetric.swift) + [`SentryMetricValue.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Protocol/SentryMetricValue.swift) (`trace_id, span_id, name, value, type, unit, attributes`)
- [`Sources/Swift/Protocol/SentryAttribute.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Protocol/SentryAttribute.swift) + [`SentryAttributeContent.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Protocol/SentryAttributeContent.swift) (attribute `type` strings `string, boolean, integer, double`, arrays → `array`)
- [`Sources/Swift/Protocol/SentryUnit.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Protocol/SentryUnit.swift)

**Spec:** [develop-docs: logs](https://develop.sentry.dev/sdk/telemetry/logs/), [attributes](https://develop.sentry.dev/sdk/telemetry/attributes/); Relay log/trace_metric item schemas.

**Check:** payload body field names and attribute `type` strings exact — area 4 only verifies the envelope item-type string; a drift here silently mis-types every log/metric attribute Relay ingests.

## 5. Client reports / discard reasons

**What it is:** When the SDK drops telemetry locally (rate-limited, sampled out, queue full) it tells Sentry via a client report listing a `reason` and `category` per drop. Relay accepts only reasons on a fixed allowlist; a wrong reason string means the drop is silently uncounted, so the data looks like it never existed.

**Cocoa:**

- [`Sources/Sentry/SentryDiscardReasonMapper.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryDiscardReasonMapper.m)
- [`Sources/Swift/Networking/SentryDiscardReason.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Networking/SentryDiscardReason.swift)
- [`Sources/Swift/Tools/SentryClientReport.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Tools/SentryClientReport.swift)
- [`Sources/Swift/Tools/SentryDiscardedEvent.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Tools/SentryDiscardedEvent.swift)
- [`Sources/Swift/Tools/SentryLogClientReport.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Tools/SentryLogClientReport.swift), [`Sources/Swift/Tools/SentryMetricClientReport.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Tools/SentryMetricClientReport.swift) (byte-count quantities for `log_byte`/`trace_metric_byte` discard reasons)
- drop sites in [`SentryHttpTransport.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryHttpTransport.m), [`SentryClient.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryClient.m), [`SentryHub.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryHub.m), [`SentryTransportAdapter.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryTransportAdapter.m)

**Relay / Spec:** [develop-docs: client reports](https://develop.sentry.dev/sdk/telemetry/client-reports/); Relay [`relay-event-schema/src/protocol/client_report.rs`](https://github.com/getsentry/relay/blob/master/relay-event-schema/src/protocol/client_report.rs), [`relay-server/src/services/outcome.rs`](https://github.com/getsentry/relay/blob/master/relay-server/src/services/outcome.rs).

**Check:** every reason string in the develop-docs allowlist (`ratelimit_backoff`, NOT `rate_limit_backoff`). Payload `{timestamp, discarded_events:[{reason, category, quantity}]}`; never populate Relay-reserved arrays (`rate_limited_events`/`filtered_events`/`filtered_sampling_events`); 429s not double-counted client-side; drops attributed to the right category.

## 6. Auth / request format

**What it is:** Every envelope POST carries the `X-Sentry-Auth` header and a fixed set of content headers and URL path. If any of these drift, Relay rejects the request outright — a hard failure, but one the SDK can cause by getting a single token or path segment wrong.

**Cocoa:**

- [`Sources/Swift/Tools/SentryURLRequestFactory.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Tools/SentryURLRequestFactory.swift)
- [`Sources/Swift/SentryDsn.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/SentryDsn.swift)
- [`Sources/Swift/Networking/SentryNSURLRequestBuilder.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Networking/SentryNSURLRequestBuilder.swift)

**Spec:** [develop-docs: overview / auth](https://develop.sentry.dev/sdk/overview/), [envelopes](https://develop.sentry.dev/sdk/data-model/envelopes/).

**Check:** `X-Sentry-Auth: Sentry sentry_version=7,sentry_client=<name>/<ver>,sentry_key=<key>`; `Content-Type: application/x-sentry-envelope`; `Content-Encoding: gzip` (body gzipped); `POST`; path `<dsn-extra-path>/api/<projectId>/envelope/`.

## 7. Dynamic Sampling Context (baggage)

**What it is:** The DSC is a set of trace-level fields (release, environment, sample rate, …) the SDK propagates in the `baggage` header and the envelope `trace` header. Relay uses it for server-side dynamic sampling. A missing or mis-serialized key means Relay samples the trace wrong, or head/tail sampling decisions diverge.

**Cocoa:**

- [`Sources/Sentry/SentryBaggage.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryBaggage.m) (`toHTTPHeaderWithOriginalBaggage:`)
- [`Sources/Sentry/SentryTraceContext.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryTraceContext.m) (`initWithDict:`, `serialize`)
- [`Sources/Swift/Core/Helper/SentryBaggageSerialization.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Core/Helper/SentryBaggageSerialization.swift)

**Spec:** [develop-docs: dynamic sampling context](https://develop.sentry.dev/sdk/foundations/trace-propagation/dynamic-sampling-context/).

**Check:** keys exactly named: `trace_id, public_key, release, environment, transaction, sample_rate, sample_rand, sampled, replay_id, org_id`; `sample_rand` (required since v1.1.0) and `org_id` (v1.2.0) generated/propagated; missing keys on any DSC path; `sample_rand`/`sample_rate` serialization precision (rounding can break `sample_rand < sample_rate ⟺ sampled`); `sentry-sampled` = `true`/`false`.

## 8. sentry-trace header

**What it is:** The `sentry-trace` header links spans across services (trace + span id + sampled flag). Wrong formatting breaks trace continuity — spans land in the wrong or no trace.

**Cocoa:**

- [`Sources/Sentry/SentryTraceHeader.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryTraceHeader.m) (`value`)

**Spec:** [develop-docs: trace propagation](https://develop.sentry.dev/sdk/foundations/trace-propagation/).

**Check:** `traceid-spanid-sampled`; 32-hex trace, 16-hex span; sampled `1`/`0`/omitted.

## 9. Sessions

**What it is:** Session envelopes drive release-health (crash-free rate). They carry a fixed field set and a strict status enum; Relay and the product aggregate on these. A wrong field name or status, or a broken init/seq dedup, silently corrupts release-health numbers.

**Cocoa:**

- [`Sources/Swift/SentrySession.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/SentrySession.swift)
- [`Sources/Swift/Helper/SentryMigrateSessionInit.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Helper/SentryMigrateSessionInit.swift)

**Spec:** [develop-docs: sessions](https://develop.sentry.dev/sdk/telemetry/sessions/).

**Check:** fields `sid, did, init, started, timestamp, status, errors, duration, seq, attrs{release, environment, ip_address, user_agent}`; status `ok/exited/crashed/abnormal` only; init/seq dedup + never-drop-init migration; `duration` omitted on init.

## 10. Sampling numbers & invariant

**What it is:** The SDK makes the sampling decision locally (`sample_rand < sample_rate`) and also transmits the numbers in the DSC. If the decision uses full precision but the transmitted value is rounded, the boundary invariant can flip — Relay would re-derive a different decision than the SDK made.

**Cocoa:**

- [`Sources/Sentry/SentrySampling.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentrySampling.m) (`_sentry_calcSample`)
- [`Sources/Sentry/SentryTraceContext.m`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/SentryTraceContext.m)

**Spec:** [develop-docs: dynamic sampling context](https://develop.sentry.dev/sdk/foundations/trace-propagation/dynamic-sampling-context/) — invariant `sample_rand < sample_rate ⟺ sampled`.

**Check:** full-precision decision vs rounded transmission; `<=` vs strict `<` at the boundary; `sample_rand` seeded once at trace start and reused.

## 11. Session Replay payloads

**What it is:** Session Replay ships as `replay_event` + `replay_recording` envelope items. Area 4 only checks the item-_type_ strings; this checks the _contents_ Relay/ingest forwards to the replay player: the rrweb-style event stream (numeric `type` codes, `timestamp`, `data`), the recording header (`segment_id`), video-segment metadata (`encoding`, `container`, `frameRateType`), and captured network-request details embedded in breadcrumbs. A drift here doesn't error — it silently produces an unplayable or mis-rendered replay, or a network panel with wrong fields.

**Cocoa:**

- [`Sources/Swift/Integrations/SessionReplay/RRWeb/SentryRRWebEvent.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Integrations/SessionReplay/RRWeb/SentryRRWebEvent.swift) (`SentryRRWebEventType` raw values `touch=3, meta=4, custom=5`)
- [`Sources/Swift/Integrations/SessionReplay/SentryReplayRecording.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Integrations/SessionReplay/SentryReplayRecording.swift) (`segment_id` header; `encoding=h264`, `container=mp4`, `frameRateType=constant`)
- [`Sources/Swift/Integrations/SessionReplay/SentryReplayEvent.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Integrations/SessionReplay/SentryReplayEvent.swift)
- [`Sources/Swift/Integrations/SessionReplay/SentryReplayNetworkDetails.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Integrations/SessionReplay/SentryReplayNetworkDetails.swift) (keys `method, statusCode, requestBodySize, responseBodySize, request, response, body, warnings, headers`)

**Relay / Spec:** [`relay-server/src/envelope/item.rs`](https://github.com/getsentry/relay/blob/master/relay-server/src/envelope/item.rs) (`ItemType::ReplayEvent`, `ItemType::ReplayRecording`); [rrweb event types](https://github.com/rrweb-io/rrweb/blob/master/packages/types/src/index.ts); [sentry-javascript replay-internal constants](https://github.com/getsentry/sentry-javascript/blob/develop/packages/replay-internal/src/constants.ts) (the frontend contract these numeric/string constants must match, per the in-file comment).

**Check:** rrweb `type` numeric codes match rrweb's `EventType`, not reassigned; `segment_id` key name and int type; video constants (`h264`/`mp4`/`constant`) match what the replay player expects; network-details key names exact, matching the frontend field names referenced in `SentryReplayNetworkDetails.swift`'s own doc comments.

## 12. User Feedback payload

**What it is:** User Feedback ships as a `feedback` envelope item (Relay `ItemType::UserReportV2` / `DataCategory::UserReportV2`, wire name `feedback`). Area 4 only checks that item-type string; this checks the JSON body Relay parses into a feedback record. A field-name or enum-value drift silently drops the feedback's name/email/associated-event linkage or produces an unrecognized `source`.

**Cocoa:**

- [`Sources/Swift/Integrations/UserFeedback/SentryFeedback.swift`](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Swift/Integrations/UserFeedback/SentryFeedback.swift) (keys `message, name, contact_email, associated_event_id, source`; `source` values `widget, custom`)

**Relay / Spec:** [`relay-server/src/envelope/item.rs`](https://github.com/getsentry/relay/blob/master/relay-server/src/envelope/item.rs) (`ItemType::UserReportV2`); [develop-docs: user feedback](https://develop.sentry.dev/sdk/data-model/envelope-items/).

**Check:** field names exact (`contact_email`, not `email`, on the wire — `email` is only used in the local `dataDictionary()` callback payload, don't confuse the two); `source` enum values `widget`/`custom` match what the product ingests; `associated_event_id` format (32-hex, no dashes).
