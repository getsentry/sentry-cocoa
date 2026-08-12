@_spi(Private) @testable import Sentry
import XCTest

/// Snapshot testing for network envelopes.
///
/// Compares a serialized ``SentryEnvelope`` against a JSON snapshot stored in
/// `Tests/Resources/NetworkEnvelopeSnapshots`. The comparison is a **strict structural match**:
/// every key in the snapshot must exist in the envelope, and every key in the envelope must exist
/// in the snapshot. Unexpected additions — a leaked PII context key, an extra span, a new field in
/// `contexts` — fail the assertion just like missing or changed values do.
///
/// Values wrapped in angle brackets, e.g. `"<timestamp>"`, are placeholders: only their presence is
/// asserted, not their content. Use them for values that change between runs (ids, timestamps,
/// device details). Paths listed in ``optionalPaths`` may be absent entirely, for values that only
/// exist on some platforms.
///
/// V10 sends a different payload, so each snapshot has a `-v10` variant that is selected
/// automatically. Both variants are compared just as strictly — V10 differences live in that file
/// rather than as exceptions in this comparison.
///
/// When the SDK intentionally changes the payload, update the snapshot files rather than weakening
/// the comparison. On failure the assertion prints both the mismatches and the actual envelope JSON,
/// so the snapshot can be updated by copying it and re-inserting the placeholders. Remember to
/// update both the default and the `-v10` snapshot.
struct NetworkEnvelopeSnapshot {
    /// Paths that may be missing from the envelope without failing the comparison.
    ///
    /// Only for values whose presence legitimately differs per platform. Everything else must be
    /// present, even if its value is a placeholder. Differences between the v9 and V10 payloads
    /// belong in the separate `-v10` snapshot instead, so both variants stay strictly compared.
    private static let optionalPaths: Set<String> = {
        var paths = Set<String>()
#if os(macOS)
        paths.formUnion([
            "$.items[0].payload.contexts.app.in_foreground",
            "$.items[0].payload.contexts.app.is_active",
            "$.items[0].payload.contexts.device.model_id"
        ])
#endif
        return paths
    }()

    private static let resourceDirectory = "Resources/NetworkEnvelopeSnapshots"

    /// Catalyst and V10 send different payloads, so each has dedicated snapshots rather than
    /// exceptions carved into the comparison.
    private static func resourceName(for resource: String) -> String {
#if targetEnvironment(macCatalyst)
        let platformResource = "\(resource)-catalyst"
#elseif os(iOS)
        let platformResource = "\(resource)-ios"
#elseif os(tvOS)
        let platformResource = "\(resource)-tvos"
#elseif os(visionOS)
        let platformResource = "\(resource)-visionos"
#else
        let platformResource = resource
#endif
#if SDK_V10
        return "\(platformResource)-v10"
#else
        return platformResource
#endif
    }

    static func assertMatches(
        envelope: SentryEnvelope,
        resource: String,
        testCase: XCTestCase,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let resource = resourceName(for: resource)
        guard let expectedURL = Bundle(for: type(of: testCase)).url(
            forResource: "\(resourceDirectory)/\(resource)",
            withExtension: "json"
        ) else {
            XCTFail("Missing network envelope snapshot \(resource).json.", file: file, line: line)
            return
        }
        guard let data = SentrySerializationSwift.data(with: envelope),
              let serializedEnvelope = SentrySerializationSwift.envelope(with: data) else {
            XCTFail("Failed to serialize network envelope.", file: file, line: line)
            return
        }

        let expected = try JSONSerialization.jsonObject(with: Data(contentsOf: expectedURL))
        let actual = try jsonObject(envelope: serializedEnvelope)

        var mismatches: [String] = []
        collectMismatches(expected: expected, actual: actual, path: "$", into: &mismatches)

        guard !mismatches.isEmpty else { return }

        XCTFail(
            try failureMessage(mismatches: mismatches, actual: actual, resource: resource),
            file: file,
            line: line
        )
    }

    /// Combines every mismatch with instructions and the actual JSON, so a single failure message
    /// explains what changed and how to update the snapshot if the change is expected.
    private static func failureMessage(
        mismatches: [String],
        actual: [String: Any],
        resource: String
    ) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: actual,
            options: [.prettyPrinted, .sortedKeys]
        )
        let actualJSON = try XCTUnwrap(String(data: data, encoding: .utf8))

        return """
        The envelope does not match the snapshot \(resource).json. \
        \(mismatches.count) mismatch(es):
        \(mismatches.map { "  - \($0)" }.joined(separator: "\n"))

        If this payload change is expected, update \
        Tests/\(resourceDirectory)/\(resource).json with the actual envelope below:
          1. Replace the file contents with the JSON printed here (keys are already sorted).
          2. Re-insert angle-bracket placeholders such as "<timestamp>" for every value that \
        changes between runs (ids, timestamps, device details), so only their presence is asserted.
        Only add entries to `optionalPaths` in NetworkEnvelopeSnapshot.swift when a value is \
        genuinely absent on some platforms — do not use it to silence unexpected keys.

        Actual envelope:
        \(actualJSON)
        """
    }

    private static func jsonObject(envelope: SentryEnvelope) throws -> [String: Any] {
        var header: [String: Any] = [:]
        header["event_id"] = envelope.header.eventId?.sentryIdString
        header["sdk"] = envelope.header.sdkInfo?.serialize()
        header["trace"] = envelope.header.traceContext?.serialize()

        let items = envelope.items.map { item -> [String: Any] in
            var payload: Any = ""
            if let data = item.data, !data.isEmpty {
                do {
                    payload = try JSONSerialization.jsonObject(with: data)
                } catch {
                    payload = ["base64": data.base64EncodedString()]
                }
            }
            return [
                "header": item.header.serialize(),
                "payload": payload
            ]
        }

        return ["header": header, "items": items]
    }

    private static func collectMismatches(
        expected: Any,
        actual: Any?,
        path: String,
        into mismatches: inout [String]
    ) {
        if let expected = expected as? String,
           expected.hasPrefix("<"),
           expected.hasSuffix(">") {
            if actual == nil && !optionalPaths.contains(path) {
                mismatches.append("Missing value at \(path).")
            }
            return
        }

        if let expected = expected as? [String: Any] {
            collectDictionaryMismatches(
                expected: expected,
                actual: actual,
                path: path,
                into: &mismatches
            )
            return
        }

        if let expected = expected as? [Any] {
            collectArrayMismatches(
                expected: expected,
                actual: actual,
                path: path,
                into: &mismatches
            )
            return
        }

        if expected as? NSObject != actual as? NSObject {
            mismatches.append(
                "Expected \(expected) at \(path), got \(String(describing: actual))."
            )
        }
    }

    private static func collectDictionaryMismatches(
        expected: [String: Any],
        actual: Any?,
        path: String,
        into mismatches: inout [String]
    ) {
        guard let actual = actual as? [String: Any] else {
            mismatches.append("Expected dictionary at \(path), got \(String(describing: actual)).")
            return
        }
        collectKeyMismatches(expected: expected, actual: actual, path: path, into: &mismatches)
        for (key, value) in expected {
            collectMismatches(
                expected: value,
                actual: actual[key],
                path: "\(path).\(key)",
                into: &mismatches
            )
        }
    }

    private static func collectArrayMismatches(
        expected: [Any],
        actual: Any?,
        path: String,
        into mismatches: inout [String]
    ) {
        guard let actual = actual as? [Any] else {
            mismatches.append("Expected array at \(path), got \(String(describing: actual)).")
            return
        }
        if actual.count != expected.count {
            mismatches.append(
                "Expected \(expected.count) element(s) at \(path), got \(actual.count)."
            )
        }
        for (index, values) in zip(expected, actual).enumerated() {
            collectMismatches(
                expected: values.0,
                actual: values.1,
                path: "\(path)[\(index)]",
                into: &mismatches
            )
        }
    }

    /// Records mismatches when the snapshot and the envelope describe different sets of keys.
    ///
    /// Recursing over the snapshot's keys alone would never visit keys that only exist in the
    /// envelope, so additive regressions would pass silently.
    private static func collectKeyMismatches(
        expected: [String: Any],
        actual: [String: Any],
        path: String,
        into mismatches: inout [String]
    ) {
        let unexpectedKeys = Set(actual.keys).subtracting(expected.keys).sorted()
        if !unexpectedKeys.isEmpty {
            mismatches.append(
                "Unexpected key(s) at \(path) not present in the snapshot: "
                    + unexpectedKeys.joined(separator: ", ") + "."
            )
        }

        let missingKeys = Set(expected.keys)
            .subtracting(actual.keys)
            .filter { !optionalPaths.contains("\(path).\($0)") }
            .sorted()
        if !missingKeys.isEmpty {
            mismatches.append(
                "Missing key(s) at \(path) expected by the snapshot: "
                    + missingKeys.joined(separator: ", ") + "."
            )
        }
    }
}
