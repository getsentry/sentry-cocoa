@_spi(Private) @testable import Sentry
import XCTest

struct NetworkEnvelopeBaseline {
    private static let updateEnvironmentVariable = "UPDATE_NETWORK_ENVELOPE_BASELINES"
    private static let replacements = [
        "event_id": "<event-id>",
        "trace_id": "<trace-id>",
        "span_id": "<span-id>",
        "parent_span_id": "<span-id>",
        "sent_at": "<timestamp>",
        "timestamp": "<timestamp>",
        "start_timestamp": "<timestamp>",
        "request_start": "<timestamp>",
        "app_start_time": "<timestamp>",
        "Date": "<timestamp>",
        "duration": "<duration>",
        "instruction_addr": "<address>",
        "symbol_addr": "<address>",
        "image_addr": "<address>",
        "image_vmaddr": "<address>",
        "debug_id": "<debug-id>",
        "code_id": "<debug-id>",
        "uuid": "<debug-id>",
        "sample_rand": "<sample-rand>",
        "baggage": "<baggage>",
        "sentry-trace": "<sentry-trace>",
        "stacktrace": "<stacktrace>",
        "threads": "<threads>",
        "debug_meta": "<debug-meta>",
        "extra": "<runtime-performance-data>",
        "measurements": "<runtime-performance-data>",
        "id": "<id>",
        "dist": "<runtime-value>",
        "thread.id": "<thread-id>"
    ]

    static func normalizedJSONObject(envelope: SentryEnvelope) throws -> Any {
        guard let serializedEnvelope = SentrySerializationSwift.data(with: envelope) else {
            throw Error.serializationFailed
        }

        var parser = EnvelopeParser(data: serializedEnvelope)
        var header = try parser.parseHeader()
        header = normalize(header) as? [String: Any] ?? header

        var items: [[String: Any]] = []
        while let item = try parser.parseItem() {
            var normalizedHeader = normalize(item.header) as? [String: Any] ?? item.header
            var normalizedPayload: Any

            if item.payload.isEmpty {
                normalizedPayload = ""
                normalizedHeader["length"] = 0
            } else {
                do {
                    let json = try JSONSerialization.jsonObject(with: item.payload)
                    normalizedPayload = normalizePayload(json)
                    normalizedHeader["length"] = try JSONSerialization.data(
                        withJSONObject: normalizedPayload,
                        options: [.sortedKeys]
                    ).count
                } catch {
                    normalizedPayload = ["base64": item.payload.base64EncodedString()]
                }
            }

            items.append([
                "header": normalizedHeader,
                "payload": normalizedPayload
            ])
        }

        return [
            "header": header,
            "items": items
        ]
    }

    static func assertMatches(
        envelope: SentryEnvelope,
        resource: String,
        testCase: XCTestCase,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actualData = try normalizedData(envelope: envelope)

        if ProcessInfo.processInfo.environment[updateEnvironmentVariable] == "1" {
            let resourceURL = sourceResourceURL(resource: resource)
            try FileManager.default.createDirectory(
                at: resourceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try actualData.write(to: resourceURL)
            return
        }

        guard let expectedURL = Bundle(for: type(of: testCase)).url(
            forResource: "Resources/NetworkEnvelopeBaselines/\(resource)",
            withExtension: "json"
        ) else {
            XCTFail(
                "Missing network envelope baseline \(resource).json. Regenerate it with \(updateEnvironmentVariable)=1.",
                file: file,
                line: line
            )
            return
        }

        let expectedData = try Data(contentsOf: expectedURL)
        let expected = try JSONSerialization.jsonObject(with: expectedData) as? NSDictionary
        let actual = try JSONSerialization.jsonObject(with: actualData) as? NSDictionary
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private static func normalizedData(envelope: SentryEnvelope) throws -> Data {
        let json = try normalizedJSONObject(envelope: envelope)
        var data = try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        data.append(UInt8(ascii: "\n"))
        return data
    }

    private static func normalize(_ value: Any, key: String? = nil) -> Any {
        if let key, ["app", "culture", "device", "os"].contains(key) {
            return normalizeRuntimeContext(value)
        }

        if let key, let replacement = replacements[key] {
            return replacement
        }

        if let dictionary = value as? [String: Any] {
            var normalized: [String: Any] = [:]
            for (nestedKey, nestedValue) in dictionary {
                normalized[nestedKey] = normalize(nestedValue, key: nestedKey)
            }
            return normalized
        }

        if let array = value as? [Any] {
            return array.map { normalize($0) }
        }

        return value
    }

    private static func normalizeRuntimeContext(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues(normalizeRuntimeContext)
        }
        if let array = value as? [Any] {
            return array.map(normalizeRuntimeContext)
        }
        return "<runtime-value>"
    }

    private static func normalizePayload(_ value: Any) -> Any {
        guard var dictionary = normalize(value) as? [String: Any] else {
            return normalize(value)
        }

        if let breadcrumbs = dictionary["breadcrumbs"] as? [[String: Any]] {
            dictionary["breadcrumbs"] = breadcrumbs.filter(isDeterministicBreadcrumb)
        }

        removeFrameMetrics(from: &dictionary)
        return dictionary
    }

    private static func isDeterministicBreadcrumb(_ breadcrumb: [String: Any]) -> Bool {
        if breadcrumb["category"] as? String == "device.connectivity" {
            return false
        }
        if breadcrumb["category"] as? String == "http",
           let data = breadcrumb["data"] as? [String: Any],
           data["url"] as? String == "" {
            return false
        }
        return true
    }

    private static func removeFrameMetrics(from value: inout [String: Any]) {
        for key in value.keys {
            if key.hasPrefix("frames.") {
                value.removeValue(forKey: key)
            } else if var dictionary = value[key] as? [String: Any] {
                removeFrameMetrics(from: &dictionary)
                value[key] = dictionary
            } else if let array = value[key] as? [[String: Any]] {
                value[key] = array.map { element in
                    var element = element
                    removeFrameMetrics(from: &element)
                    return element
                }
            }
        }
    }

    private static func sourceResourceURL(resource: String) -> URL {
        var testsDirectory = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 {
            testsDirectory.deleteLastPathComponent()
        }
        return testsDirectory
            .appendingPathComponent("Resources/NetworkEnvelopeBaselines", isDirectory: true)
            .appendingPathComponent("\(resource).json")
    }

    private enum Error: Swift.Error {
        case serializationFailed
        case malformedEnvelope
    }

    private struct EnvelopeParser {
        private let data: Data
        private var offset = 0

        init(data: Data) {
            self.data = data
        }

        mutating func parseHeader() throws -> [String: Any] {
            try parseJSONLine()
        }

        mutating func parseItem() throws -> (header: [String: Any], payload: Data)? {
            guard offset < data.count else {
                return nil
            }

            let header = try parseJSONLine()
            guard let length = (header["length"] as? NSNumber)?.intValue,
                  length >= 0,
                  offset + length <= data.count else {
                throw Error.malformedEnvelope
            }

            let payload = data.subdata(in: offset..<(offset + length))
            offset += length
            if offset < data.count {
                guard data[offset] == UInt8(ascii: "\n") else {
                    throw Error.malformedEnvelope
                }
                offset += 1
            }
            return (header, payload)
        }

        private mutating func parseJSONLine() throws -> [String: Any] {
            guard let newline = data[offset...].firstIndex(of: UInt8(ascii: "\n")) else {
                throw Error.malformedEnvelope
            }

            let line = data.subdata(in: offset..<newline)
            offset = newline + 1
            guard let json = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                throw Error.malformedEnvelope
            }
            return json
        }
    }
}
