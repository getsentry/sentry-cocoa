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
    
    func testProcessLog_WithValidLog_CreatesEnvelopeAndCallsClient() {
        // Given
        let log = createTestLog()
        
        // When
        sut.processLog(log, with: scope)
        
        // Then
        XCTAssertEqual(testClient.captureEnvelopeInvocations.count, 1)
        
        let sentEnvelope = testClient.captureEnvelopeInvocations.first!
        XCTAssertEqual(sentEnvelope.items.count, 1)
        
        let envelopeItem = sentEnvelope.items.first!
        XCTAssertEqual(envelopeItem.header.type, "log")
        XCTAssertEqual(envelopeItem.header.contentType, "application/vnd.sentry.items.log+json")
        XCTAssertEqual(envelopeItem.header.itemCount?.intValue, 1)
        XCTAssertGreaterThan(envelopeItem.header.length, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestLog(
        level: SentryLog.Level = .info,
        body: String = "Test log message",
        attributes: [String: SentryLog.Attribute] = [:]
    ) -> SentryLog {
        return SentryLog(
            timestamp: Date(),
            level: level,
            body: body,
            attributes: attributes
        )
    }
}
