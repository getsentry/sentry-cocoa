@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryLogBatcherTests: XCTestCase {
    
    private var mockDelegate: MockSentryLogBatcherDelegate!
    private var sut: SentryLogBatcher!
    private var scope: Scope!
    
    override func setUp() {
        super.setUp()
        mockDelegate = MockSentryLogBatcherDelegate()
        sut = SentryLogBatcher(delegate: mockDelegate)
        scope = Scope()
    }
    
    override func tearDown() {
        super.tearDown()
        mockDelegate = nil
        sut = nil
        scope = nil
    }
    
    func testProcessLog_WithValidLog_CreatesEnvelopeAndCallsDelegate() throws {
        let log = createTestLog()
        
        sut.processLog(log, with: scope)
        
        XCTAssertEqual(mockDelegate.sendInvocations.count, 1)
        
        let sentEnvelope = try XCTUnwrap(mockDelegate.sendInvocations.first)
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

// MARK: - Mock Delegate

private class MockSentryLogBatcherDelegate: NSObject, SentryLogBatcherDelegate {
    var sendInvocations = Invocations<SentryEnvelope>()
    
    func send(_ envelope: SentryEnvelope) {
        sendInvocations.record(envelope)
    }
}
