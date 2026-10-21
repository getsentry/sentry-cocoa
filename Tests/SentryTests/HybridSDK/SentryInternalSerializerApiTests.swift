#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryInternalSerializerApiTests: XCTestCase {

    func testSerialize_whenScopeContainsData_shouldReturnWireFormat() throws {
        // -- Arrange --
        let scope = Scope()
        scope.setTag(value: "value", key: "tag")
        scope.setContext(value: ["key": "value"], key: "custom")
        let user = User()
        user.userId = "user-id"
        scope.setUser(user)
        let sut = SentryInternalSerializerApi()

        // -- Act --
        let serialized = sut.serialize(scope: scope)

        // -- Assert --
        XCTAssertEqual((serialized["tags"] as? [String: String])?["tag"], "value")
        let contexts = try XCTUnwrap(serialized["context"] as? [String: [String: Any]])
        XCTAssertEqual(contexts["custom"]?["key"] as? String, "value")
        XCTAssertEqual((serialized["user"] as? [String: Any])?["id"] as? String, "user-id")
        XCTAssertTrue(JSONSerialization.isValidJSONObject(serialized))
    }

    func testSerialize_whenDebugMetaContainsData_shouldReturnWireFormat() {
        // -- Arrange --
        let debugMeta = DebugMeta()
        debugMeta.debugID = "debug-id"
        debugMeta.type = "macho"
        debugMeta.codeFile = "/app/binary"
        debugMeta.imageAddress = "0x1000"
        debugMeta.imageSize = 4_096
        let sut = SentryInternalSerializerApi()

        // -- Act --
        let serialized = sut.serialize(debugMeta: debugMeta)

        // -- Assert --
        XCTAssertEqual(serialized["debug_id"] as? String, "debug-id")
        XCTAssertEqual(serialized["type"] as? String, "macho")
        XCTAssertEqual(serialized["code_file"] as? String, "/app/binary")
        XCTAssertEqual(serialized["image_addr"] as? String, "0x1000")
        XCTAssertEqual(serialized["image_size"] as? Int, 4_096)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(serialized))
    }

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
