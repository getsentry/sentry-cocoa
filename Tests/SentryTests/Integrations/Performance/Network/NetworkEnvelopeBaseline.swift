@_spi(Private) @testable import Sentry
import XCTest

struct NetworkEnvelopeBaseline {
    private static let optionalPaths: Set<String> = {
        var paths = Set<String>()
#if os(macOS)
        paths.formUnion([
            "$.items[0].payload.contexts.app.in_foreground",
            "$.items[0].payload.contexts.app.is_active",
            "$.items[0].payload.contexts.device.model_id"
        ])
#endif
#if SDK_V10
        paths.insert("$.items[0].payload.contexts.device.locale")
#endif
        return paths
    }()

    static func assertMatches(
        envelope: SentryEnvelope,
        resource: String,
        testCase: XCTestCase,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        guard let expectedURL = Bundle(for: type(of: testCase)).url(
            forResource: "Resources/NetworkEnvelopeBaselines/\(resource)",
            withExtension: "json"
        ) else {
            XCTFail("Missing network envelope baseline \(resource).json.", file: file, line: line)
            return
        }
        guard let data = SentrySerializationSwift.data(with: envelope),
              let serializedEnvelope = SentrySerializationSwift.envelope(with: data) else {
            XCTFail("Failed to serialize network envelope.", file: file, line: line)
            return
        }

        let expected = try JSONSerialization.jsonObject(with: Data(contentsOf: expectedURL))
        let actual = try jsonObject(envelope: serializedEnvelope)
        assertContains(expected: expected, actual: actual, path: "$", file: file, line: line)
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

    private static func assertContains(
        expected: Any,
        actual: Any?,
        path: String,
        file: StaticString,
        line: UInt
    ) {
        if let expected = expected as? String,
           expected.hasPrefix("<"),
           expected.hasSuffix(">") {
            if !optionalPaths.contains(path) {
                XCTAssertNotNil(actual, "Missing value at \(path).", file: file, line: line)
            }
            return
        }

        if let expected = expected as? [String: Any] {
            guard let actual = actual as? [String: Any] else {
                return XCTFail("Expected dictionary at \(path), got \(String(describing: actual)).", file: file, line: line)
            }
            for (key, value) in expected {
                assertContains(
                    expected: value,
                    actual: actual[key],
                    path: "\(path).\(key)",
                    file: file,
                    line: line
                )
            }
            return
        }

        if let expected = expected as? [Any] {
            guard let actual = actual as? [Any] else {
                return XCTFail("Expected array at \(path), got \(String(describing: actual)).", file: file, line: line)
            }
            XCTAssertEqual(actual.count, expected.count, "Unexpected element count at \(path).", file: file, line: line)
            for (index, values) in zip(expected, actual).enumerated() {
                assertContains(
                    expected: values.0,
                    actual: values.1,
                    path: "\(path)[\(index)]",
                    file: file,
                    line: line
                )
            }
            return
        }

#if SDK_V10
        if path.hasSuffix(".sdk.settings.infer_ip") {
            XCTAssertEqual("auto", actual as? String, "Unexpected value at \(path).", file: file, line: line)
            return
        }
#endif
        XCTAssertEqual(
            expected as? NSObject,
            actual as? NSObject,
            "Unexpected value at \(path).",
            file: file,
            line: line
        )
    }
}
