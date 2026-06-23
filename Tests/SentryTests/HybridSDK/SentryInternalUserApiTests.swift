@testable import Sentry
import SentryTestUtils
import XCTest

class SentryInternalUserApiTests: XCTestCase {

    private var sut: SentryInternalUserApi { SentrySDK.internal.user }

    override func setUp() {
        super.setUp()
        SentrySDK.start {
            $0.dsn = TestConstants.dsnForTestCase(type: SentryInternalUserApiTests.self)
            $0.removeAllIntegrations()
        }
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testFromDictionary_whenPopulated_shouldMapFields() {
        // -- Arrange --
        let dict: [String: Any] = [
            "id": "user123",
            "email": "test@example.com",
            "username": "testuser",
            "ip_address": "127.0.0.1"
        ]

        // -- Act --
        let user = sut.fromDictionary(dict)

        // -- Assert --
        XCTAssertEqual(user.userId, "user123")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.username, "testuser")
        XCTAssertEqual(user.ipAddress, "127.0.0.1")
    }

    func testFromDictionary_whenEmpty_shouldReturnUser() {
        // -- Arrange --
        let dict: [String: Any] = [:]

        // -- Act --
        let user = sut.fromDictionary(dict)

        // -- Assert --
        XCTAssertNotNil(user)
    }

    func testFromDictionary_whenDataPresent_shouldIncludeData() {
        // -- Arrange --
        let dict: [String: Any] = [
            "id": "user123",
            "data": ["role": "admin"]
        ]

        // -- Act --
        let user = sut.fromDictionary(dict)

        // -- Assert --
        XCTAssertEqual(user.data?["role"] as? String, "admin")
    }
}
