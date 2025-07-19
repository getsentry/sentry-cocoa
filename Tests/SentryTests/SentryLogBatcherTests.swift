@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryLogBatcherTests: XCTestCase {
    
    private var options: Options!
    private var testClient: TestClient!
    private var sut: SentryLogBatcher!
    private var scope: Scope!
    
    override func setUp() {
        super.setUp()
        
        options = Options()
        options.experimental.enableLogs = true
        
        testClient = TestClient(options: options)
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
    
    func testAddLog_WithValidLog_CallsCaptureLogsData() throws {
        // Given
        let log = createTestLog()
        
        // When
        sut.add(log)
        
        // Then
        XCTAssertEqual(testClient.captureLogsDataInvocations.count, 1)
        
        let sentData = try XCTUnwrap(testClient.captureLogsDataInvocations.first)
        
        // Verify the data contains the expected JSON structure
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: sentData) as? [String: Any])
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
            traceId: SentryId.empty,
            level: level,
            body: body,
            attributes: attributes
        )
    }
}
