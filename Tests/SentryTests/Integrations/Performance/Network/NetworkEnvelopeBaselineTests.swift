@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

final class NetworkEnvelopeBaselineTests: XCTestCase {

    func testNormalizedJSONObject_whenRuntimeValuesDiffer_shouldProduceSameBaseline() throws {
        // -- Arrange --
        let first = SentryEnvelope(
            id: SentryId(uuidString: "11111111-1111-1111-1111-111111111111"),
            singleItem: SentryEnvelopeItem(type: "event", data: try eventData(
                eventID: "11111111111111111111111111111111",
                traceID: "22222222222222222222222222222222",
                spanID: "3333333333333333",
                timestamp: "2026-08-06T10:00:00.000Z",
                address: "0x0000000101234567"
            ), contentType: "application/json", itemCount: 1)
        )
        first.header.sentAt = Date(timeIntervalSince1970: 1_786_009_200)

        let second = SentryEnvelope(
            id: SentryId(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
            singleItem: SentryEnvelopeItem(type: "event", data: try eventData(
                eventID: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                traceID: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                spanID: "cccccccccccccccc",
                timestamp: "2026-08-06T11:00:00.000Z",
                address: "0x0000000107654321"
            ), contentType: "application/json", itemCount: 1)
        )
        second.header.sentAt = Date(timeIntervalSince1970: 1_786_012_800)

        // -- Act --
        let firstBaseline = try NetworkEnvelopeBaseline.normalizedJSONObject(envelope: first)
        let secondBaseline = try NetworkEnvelopeBaseline.normalizedJSONObject(envelope: second)

        // -- Assert --
        XCTAssertEqual(firstBaseline as? NSDictionary, secondBaseline as? NSDictionary)
    }

    func testNormalizedJSONObject_whenMachineContextAndStacktraceDiffer_shouldProduceSameBaseline() throws {
        // -- Arrange --
        let first = try envelope(payload: [
            "breadcrumbs": [
                ["category": "device.connectivity"],
                ["category": "http", "data": ["url": ""]],
                ["category": "http", "data": ["url": "http://localhost:8081/request"]]
            ],
            "contexts": [
                "app": ["app_memory": 1, "app_start_time": "2026-08-06T10:00:00Z"],
                "device": ["free_memory": 2, "model": "iPhone17,1"],
                "os": ["version": "18.4", "kernel_version": "first"],
                "trace": ["data": ["frames.delay": 1, "frames.total": 2]]
            ],
            "debug_meta": ["images": [["code_file": "/first", "image_addr": "0x1"]]],
            "exception": ["values": [["stacktrace": ["frames": [["package": "/first"]]]]]],
            "threads": ["values": [["id": 1]]],
            "request": [
                "headers": [
                    "baggage": "sentry-environment=test,sentry-trace_id=11111111111111111111111111111111",
                    "sentry-trace": "11111111111111111111111111111111-2222222222222222-0"
                ]
            ],
            "user": ["id": "first-user"]
        ])
        let second = try envelope(payload: [
            "breadcrumbs": [
                ["category": "http", "data": ["url": "http://localhost:8081/request"]]
            ],
            "contexts": [
                "app": ["app_memory": 3, "app_start_time": "2026-08-06T11:00:00Z"],
                "device": ["free_memory": 4, "model": "iPhone18,1"],
                "os": ["version": "19.0", "kernel_version": "second"],
                "trace": ["data": ["frames.delay": 3]]
            ],
            "debug_meta": ["images": [["code_file": "/second", "image_addr": "0x2"]]],
            "exception": ["values": [["stacktrace": ["frames": [["package": "/second"]]]]]],
            "threads": ["values": [["id": 9], ["id": 10]]],
            "request": [
                "headers": [
                    "baggage": "sentry-environment=test,sentry-trace_id=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    "sentry-trace": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-0"
                ]
            ],
            "user": ["id": "second-user"]
        ])

        // -- Act --
        let firstBaseline = try NetworkEnvelopeBaseline.normalizedJSONObject(envelope: first)
        let secondBaseline = try NetworkEnvelopeBaseline.normalizedJSONObject(envelope: second)

        // -- Assert --
        XCTAssertEqual(firstBaseline as? NSDictionary, secondBaseline as? NSDictionary)
    }

    func testNormalizedJSONObject_whenPayloadChanges_shouldPreserveDifference() throws {
        // -- Arrange --
        let first = SentryEnvelope(
            id: SentryId(uuidString: "11111111-1111-1111-1111-111111111111"),
            singleItem: SentryEnvelopeItem(type: "event", data: try eventData(
                eventID: "11111111111111111111111111111111",
                traceID: "22222222222222222222222222222222",
                spanID: "3333333333333333",
                timestamp: "2026-08-06T10:00:00.000Z",
                address: "0x0000000101234567",
                statusCode: 200
            ), contentType: "application/json", itemCount: 1)
        )
        let second = SentryEnvelope(
            id: SentryId(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
            singleItem: SentryEnvelopeItem(type: "event", data: try eventData(
                eventID: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                traceID: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                spanID: "cccccccccccccccc",
                timestamp: "2026-08-06T11:00:00.000Z",
                address: "0x0000000107654321",
                statusCode: 400
            ), contentType: "application/json", itemCount: 1)
        )

        // -- Act --
        let firstBaseline = try NetworkEnvelopeBaseline.normalizedJSONObject(envelope: first)
        let secondBaseline = try NetworkEnvelopeBaseline.normalizedJSONObject(envelope: second)

        // -- Assert --
        XCTAssertNotEqual(firstBaseline as? NSDictionary, secondBaseline as? NSDictionary)
    }

    private func envelope(payload: [String: Any]) throws -> SentryEnvelope {
        let data = try JSONSerialization.data(withJSONObject: payload)
        return SentryEnvelope(
            id: SentryId(),
            singleItem: SentryEnvelopeItem(
                type: "event",
                data: data,
                contentType: "application/json",
                itemCount: 1
            )
        )
    }

    private func eventData(
        eventID: String,
        traceID: String,
        spanID: String,
        timestamp: String,
        address: String,
        statusCode: Int = 200
    ) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "event_id": eventID,
            "timestamp": timestamp,
            "contexts": [
                "trace": [
                    "trace_id": traceID,
                    "span_id": spanID
                ]
            ],
            "exception": [
                "values": [[
                    "stacktrace": [
                        "frames": [["instruction_addr": address]]
                    ]
                ]]
            ],
            "request": ["url": "http://localhost:8081/request"],
            "response": ["status_code": statusCode]
        ])
    }
}
