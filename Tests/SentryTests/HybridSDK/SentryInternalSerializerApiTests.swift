@_spi(Private) @testable import Sentry
import XCTest

final class SentryInternalSerializerApiTests: XCTestCase {

    func testSerialize_whenEventContainsData_shouldReturnWireFormat() throws {
        // -- Arrange --
        let event = Event()
        event.message = SentryMessage(formatted: "test message")
        event.tags = ["tag": "value"]
        event.context = ["custom": ["key": "value"]]
        let sut = SentryInternalSerializerApi()

        // -- Act --
        let serialized = sut.serialize(event: event)

        // -- Assert --
        let message = try XCTUnwrap(serialized["message"] as? [String: Any])
        let tags = try XCTUnwrap(serialized["tags"] as? [String: String])
        let contexts = try XCTUnwrap(serialized["contexts"] as? [String: [String: Any]])
        XCTAssertEqual(message["formatted"] as? String, "test message")
        XCTAssertEqual(tags["tag"], "value")
        XCTAssertEqual(contexts["custom"]?["key"] as? String, "value")
    }
}
