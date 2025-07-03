@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryLogBatcherTests: XCTestCase {
    
    private var testClient: TestClient!
    private var sut: SentryLogBatcher!
    private var scope: Scope!
    
    override func setUp() {
        super.setUp()
        testClient = TestClient(options: Options())
        sut = SentryLogBatcher(client: testClient)
        scope = Scope()
    }
    
    override func tearDown() {
        super.tearDown()
        testClient = nil
        sut = nil
        scope = nil
    }
    
    // MARK: - ProcessLog Tests
    
    func testAddLog_WithValidLog_CreatesEnvelopeAndCallsClient() throws {
        // Given
        let log = createTestLog()
        
        // When
        sut.add(log)
        
        // Then
        XCTAssertEqual(testClient.captureEnvelopeInvocations.count, 1)
        
        let sentEnvelope = testClient.captureEnvelopeInvocations.first!
        XCTAssertEqual(sentEnvelope.items.count, 1)
        
        let envelopeItem = sentEnvelope.items.first!
        XCTAssertEqual(envelopeItem.header.type, "log")
        XCTAssertEqual(envelopeItem.header.contentType, "application/vnd.sentry.items.log+json")
        XCTAssertEqual(envelopeItem.header.itemCount?.intValue, 1)
        XCTAssertGreaterThan(envelopeItem.header.length, 0)
        
        // Verify envelope item data contains the expected JSON structure
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: envelopeItem.data) as? [String: Any])
        let items = try XCTUnwrap(jsonObject["items"] as? [[String: Any]])
        XCTAssertEqual(1, items.count)
        
        let firstLog = items[0]
        XCTAssertEqual(1_627_846_801, firstLog["timestamp"] as? TimeInterval)
        XCTAssertEqual("info", firstLog["level"] as? String)
        XCTAssertEqual("Test log message", firstLog["body"] as? String)
    }
    
    // MARK: - Helper Methods
    
    private func createTestLog(
        level: SentryLog.Level = .info,
        body: String = "Test log message",
        attributes: [String: SentryLog.Attribute] = [:]
    ) -> SentryLog {
        return SentryLog(
            timestamp: Date(timeIntervalSince1970: 1_627_846_801),
            level: level,
            body: body,
            attributes: attributes
        )
    }
}
