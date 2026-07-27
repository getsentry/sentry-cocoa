# Surface map

One subagent per section. Paths relative to repo root. If a path is missing (Cocoa or Relay), search for the named symbol and note the move in the report.

- Relay raw base: `https://raw.githubusercontent.com/getsentry/relay/master/`
- Develop-docs base: `https://develop.sentry.dev/sdk/`

## 1. HTTP header reads — case-sensitivity

- **Cocoa:** `Sources/Sentry/SentryNetworkTracker.m`, `Sources/Sentry/SentryTracePropagation.m`, `Sources/Swift/Networking/DefaultRateLimits.swift`, `Sources/Swift/Core/Tools/URLSessionTaskHelper.swift`, `Sources/Swift/Tools/SentryURLRequestFactory.swift`
- **Spec:** RFC 9113 §8.2.1 / RFC 9114 §4.2 — HTTP/2/3 lowercase field names on the wire
- **Check:** every single-header read. `allHeaderFields[...]` / `allHTTPHeaderFields[...]` subscripts are case-SENSITIVE → unsafe (especially on a response). `valueForHTTPHeaderField:` / `value(forHTTPHeaderFieldCaseInsensitive:)` are safe. Whole-dictionary iteration is fine. Also check the guards: `.swiftlint.yml` `avoid_all_header_fields`, `scripts/check-objc-banned-pattern.sh`, whether any CI workflow runs the ObjC linter.

## 2. Rate-limit / Retry-After parsing

- **Cocoa:** `Sources/Swift/Networking/RateLimitParser.swift`, `RetryAfterHeaderParser.swift`, `DefaultRateLimits.swift`
- **Spec:** `expected-features/rate-limiting/`; Relay `relay-quotas/`
- **Check:** `X-Sentry-Rate-Limits` format `retry_after:categories:scope:reason_code:namespaces`, comma-separated. Ignore spaces; empty categories → all; all-unknown categories → limit ignored (never applied to `default`); `metric_bucket` namespaces; 429 + `Retry-After` → all categories; 429 bare → 60s all. Both header reads must be case-insensitive (HTTP/2/3 lowercase field names on the wire; a case-sensitive miss silently drops the header — HIGH).

## 3. Data categories

- **Cocoa:** `Sources/Swift/Networking/SentryDataCategory.swift`, `SentryDataCategory+EnvelopeItemType.swift`
- **Relay:** `relay-base-schema/src/data_category.rs` (`DataCategory` names + discriminants)
- **Check:** every name Cocoa emits/parses matches Relay `name()`/`from_name` exactly (lowercase). Flag: name mismatch; Relay categories Cocoa maps to `.unknown` (esp. newly added); the `profile_chunk` item → `profile_chunk_ui` category inference; any numeric index on the wire (must be none — raw values intentionally differ from Relay's).

## 4. Envelope item types

- **Cocoa:** `Sources/Swift/Helper/SentryEnvelopeItemType.swift`, `Sources/Swift/Tools/SentryEnvelopeItem.swift` (incl. replay msgpack keys), `Sources/Sentry/Profiling/SentryProfilerSerialization.m`, `Sources/Swift/Tools/TelemetryProcessor/TelemetryScheduler.swift`
- **Relay:** `relay-server/src/envelope/item.rs` (`ItemType::from_str`); spec `data-model/envelope-items/`
- **Check:** every emitted item-type string recognized by `ItemType::from_str` with exact casing (`log`, not `otel_log`). Flag unrecognized types and literals bypassing the `SentryEnvelopeItemTypes` constants. Item-header `content_type` strings (`application/vnd.sentry.items.log+json`, `application/vnd.sentry.items.trace-metric+json` in `TelemetryScheduler.swift`) must match what Relay routes on.

## 4b. Envelope headers & attachment types

- **Cocoa:** `Sources/Swift/Helper/SentrySerializationSwift.swift` (envelope header write/parse), `Sources/Swift/Tools/SentryEnvelopeHeader.swift`, `Sources/Sentry/SentryEnvelopeItemHeader.m` (keys `type, length, content_type, filename, platform, item_count`), `Sources/Sentry/SentryEnvelopeAttachmentHeader.m` + `SentryAttachment.m` (`attachment_type` values)
- **Relay:** `relay-server/src/envelope/item.rs` (`AttachmentType` enum, item-header parsing); spec `data-model/envelopes/`, `data-model/envelope-items/`
- **Check:** envelope-header keys exactly `event_id, sdk, trace, sent_at` (`sent_at` drives clock-drift correction; `trace` wraps the DSC from §7); item-header key names exact (`item_count`, `content_type`); every emitted `attachment_type` value in Relay's `AttachmentType` enum (`event.attachment`, `event.view_hierarchy`, …) — an unknown value changes how Relay treats the attachment.

## 4c. Log / metric item payloads & attributes

- **Cocoa:** `Sources/Swift/Protocol/SentryLog.swift` (keys `trace_id, span_id, severity_number, body, level`), `SentryMetric.swift` + `SentryMetricValue.swift` (`trace_id, span_id, name, value, type, unit, attributes`), `SentryAttribute.swift` + `SentryAttributeContent.swift` (attribute `type` strings `string, boolean, integer, double`, arrays → `array`), `SentryUnit.swift`
- **Spec:** `telemetry/logs/`, `telemetry/attributes/`; Relay log/trace_metric item schemas
- **Check:** payload body field names and attribute `type` strings exact — area 4 only verifies the envelope item-type string; a drift here silently mis-types every log/metric attribute Relay ingests.

## 5. Client reports / discard reasons

- **Cocoa:** `Sources/Sentry/SentryDiscardReasonMapper.m`, `Sources/Swift/Networking/SentryDiscardReason.swift`, `Sources/Swift/Tools/SentryClientReport.swift`, `SentryDiscardedEvent.swift`; drop sites in `SentryHttpTransport.m`, `SentryClient.m`, `SentryHub.m`, `SentryTransportAdapter.m`
- **Spec:** `telemetry/client-reports/`; Relay `relay-event-schema/src/protocol/client_report.rs`, `relay-server/src/services/outcome.rs`
- **Check:** every reason string in the develop-docs allowlist (`ratelimit_backoff`, NOT `rate_limit_backoff`). Payload `{timestamp, discarded_events:[{reason, category, quantity}]}`; never populate Relay-reserved arrays (`rate_limited_events`/`filtered_events`/`filtered_sampling_events`); 429s not double-counted client-side; drops attributed to the right category.

## 6. Auth / request format

- **Cocoa:** `Sources/Swift/Tools/SentryURLRequestFactory.swift`, `Sources/Swift/SentryDsn.swift`, `Sources/Swift/Networking/SentryNSURLRequestBuilder.swift`
- **Spec:** `overview/` (auth), `data-model/envelopes/`
- **Check:** `X-Sentry-Auth: Sentry sentry_version=7,sentry_client=<name>/<ver>,sentry_key=<key>`; `Content-Type: application/x-sentry-envelope`; `Content-Encoding: gzip` (body gzipped); `POST`; path `<dsn-extra-path>/api/<projectId>/envelope/`.

## 7. Dynamic Sampling Context (baggage)

- **Cocoa:** `Sources/Sentry/SentryBaggage.m` (`toHTTPHeaderWithOriginalBaggage:`), `Sources/Sentry/SentryTraceContext.m` (`initWithDict:`, `serialize`), `Sources/Swift/Core/Helper/SentryBaggageSerialization.swift`
- **Spec:** `foundations/trace-propagation/dynamic-sampling-context/`
- **Check:** keys exactly named: `trace_id, public_key, release, environment, transaction, sample_rate, sample_rand, sampled, replay_id, org_id`; `sample_rand` (required since v1.1.0) and `org_id` (v1.2.0) generated/propagated; missing keys on any DSC path; `sample_rand`/`sample_rate` serialization precision (rounding can break `sample_rand < sample_rate ⟺ sampled`); `sentry-sampled` = `true`/`false`.

## 8. sentry-trace header

- **Cocoa:** `Sources/Sentry/SentryTraceHeader.m` (`value`); spec `foundations/trace-propagation/`
- **Check:** `traceid-spanid-sampled`; 32-hex trace, 16-hex span; sampled `1`/`0`/omitted.

## 9. Sessions

- **Cocoa:** `Sources/Swift/SentrySession.swift`, `Sources/Swift/Helper/SentryMigrateSessionInit.swift`; spec `telemetry/sessions/`
- **Check:** fields `sid, did, init, started, timestamp, status, errors, duration, seq, attrs{release, environment, ip_address, user_agent}`; status `ok/exited/crashed/abnormal` only; init/seq dedup + never-drop-init migration; `duration` omitted on init.

## 10. Sampling numbers & invariant

- **Cocoa:** `Sources/Sentry/SentrySampling.m` (`_sentry_calcSample`), `Sources/Sentry/SentryTraceContext.m`
- **Spec:** DSC page invariant `sample_rand < sample_rate ⟺ sampled`
- **Check:** full-precision decision vs rounded transmission; `<=` vs strict `<` at the boundary; `sample_rand` seeded once at trace start and reused.
