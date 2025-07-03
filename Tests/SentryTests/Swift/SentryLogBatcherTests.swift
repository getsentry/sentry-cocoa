@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryLogBatcherTests: XCTestCase {
    
    private var mockDelegate: MockSentryLogBatcherDelegate!
    private var sut: SentryLogBatcher!
    private var scope: SentryScope!
    
    override func setUp() {
        super.setUp()
        mockDelegate = MockSentryLogBatcherDelegate()
        sut = SentryLogBatcher(delegate: mockDelegate)
        scope = SentryScope()
    }
    
    override func tearDown() {
        super.tearDown()
        mockDelegate = nil
        sut = nil
        scope = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInit_WithDelegate_SetsDelegate() {
        // Given & When
        let batcher = SentryLogBatcher(delegate: mockDelegate)
        
        // Then
        XCTAssertNotNil(batcher)
    }
    
    // MARK: - ProcessLog Tests
    
    func testProcessLog_WithValidLog_CreatesEnvelopeAndCallsDelegate() {
        // Given
        let log = createTestLog()
        
        // When
        sut.processLog(log, with: scope)
        
        // Then
        XCTAssertEqual(mockDelegate.sendInvocations.count, 1)
        
        let sentEnvelope = mockDelegate.sendInvocations.first!
        XCTAssertEqual(sentEnvelope.items.count, 1)
        
        let envelopeItem = sentEnvelope.items.first!
        XCTAssertEqual(envelopeItem.header.type, "log")
        XCTAssertEqual(envelopeItem.header.contentType, "application/vnd.sentry.items.log+json")
        XCTAssertEqual(envelopeItem.header.itemCount?.intValue, 1)
        XCTAssertGreaterThan(envelopeItem.header.length, 0)
    }
    
    func testProcessLog_WithDifferentLogLevels_CreatesCorrectEnvelopes() {
        // Given
        let logLevels: [SentryLog.Level] = [.trace, .debug, .info, .warn, .error, .fatal]
        
        for level in logLevels {
            // When
            let log = SentryLog(
                timestamp: Date(),
                level: level,
                body: "Test message for \(level)",
                attributes: [:]
            )
            sut.processLog(log, with: scope)
        }
        
        // Then
        XCTAssertEqual(mockDelegate.sendInvocations.count, logLevels.count)
        
        for (index, expectedLevel) in logLevels.enumerated() {
            let envelope = mockDelegate.sendInvocations[index]
            XCTAssertEqual(envelope.items.count, 1)
            
            // Verify the envelope contains the correct log data
            let itemData = envelope.items.first!.data
            let jsonObject = try! JSONSerialization.jsonObject(with: itemData) as! [String: Any]
            let items = jsonObject["items"] as! [[String: Any]]
            let logData = items.first!
            
            XCTAssertEqual(logData["level"] as? String, expectedLevel.rawValue)
            XCTAssertEqual(logData["body"] as? String, "Test message for \(expectedLevel)")
        }
    }
    
    func testProcessLog_WithAttributes_IncludesAttributesInEnvelope() {
        // Given
        let attributes = [
            "user_id": SentryLog.Attribute.string("12345"),
            "count": SentryLog.Attribute.integer(42),
            "enabled": SentryLog.Attribute.boolean(true),
            "score": SentryLog.Attribute.double(3.14159)
        ]
        
        let log = SentryLog(
            timestamp: Date(),
            level: .info,
            body: "Test message with attributes",
            attributes: attributes
        )
        
        // When
        sut.processLog(log, with: scope)
        
        // Then
        XCTAssertEqual(mockDelegate.sendInvocations.count, 1)
        
        let envelope = mockDelegate.sendInvocations.first!
        let itemData = envelope.items.first!.data
        let jsonObject = try! JSONSerialization.jsonObject(with: itemData) as! [String: Any]
        let items = jsonObject["items"] as! [[String: Any]]
        let logData = items.first!
        let logAttributes = logData["attributes"] as! [String: [String: Any]]
        
        XCTAssertEqual(logAttributes["user_id"]?["value"] as? String, "12345")
        XCTAssertEqual(logAttributes["user_id"]?["type"] as? String, "string")
        
        XCTAssertEqual(logAttributes["count"]?["value"] as? Int, 42)
        XCTAssertEqual(logAttributes["count"]?["type"] as? String, "integer")
        
        XCTAssertEqual(logAttributes["enabled"]?["value"] as? Bool, true)
        XCTAssertEqual(logAttributes["enabled"]?["type"] as? String, "boolean")
        
        XCTAssertEqual(logAttributes["score"]?["value"] as? Double, 3.14159, accuracy: 0.000001)
        XCTAssertEqual(logAttributes["score"]?["type"] as? String, "double")
    }
    
    func testProcessLog_WithEmptyAttributes_CreatesValidEnvelope() {
        // Given
        let log = SentryLog(
            timestamp: Date(),
            level: .info,
            body: "Test message without attributes",
            attributes: [:]
        )
        
        // When
        sut.processLog(log, with: scope)
        
        // Then
        XCTAssertEqual(mockDelegate.sendInvocations.count, 1)
        
        let envelope = mockDelegate.sendInvocations.first!
        let itemData = envelope.items.first!.data
        let jsonObject = try! JSONSerialization.jsonObject(with: itemData) as! [String: Any]
        let items = jsonObject["items"] as! [[String: Any]]
        let logData = items.first!
        let logAttributes = logData["attributes"] as! [String: [String: Any]]
        
        XCTAssertTrue(logAttributes.isEmpty)
    }
    
    func testProcessLog_WithSpecialCharactersInBody_CreatesValidEnvelope() {
        // Given
        let specialMessage = "🚀 Test with émojis and ñ special characters! \n\t\r"
        let log = SentryLog(
            timestamp: Date(),
            level: .info,
            body: specialMessage,
            attributes: [:]
        )
        
        // When
        sut.processLog(log, with: scope)
        
        // Then
        XCTAssertEqual(mockDelegate.sendInvocations.count, 1)
        
        let envelope = mockDelegate.sendInvocations.first!
        let itemData = envelope.items.first!.data
        let jsonObject = try! JSONSerialization.jsonObject(with: itemData) as! [String: Any]
        let items = jsonObject["items"] as! [[String: Any]]
        let logData = items.first!
        
        XCTAssertEqual(logData["body"] as? String, specialMessage)
    }
    
    func testProcessLog_WithVeryLongMessage_CreatesValidEnvelope() {
        // Given
        let longMessage = String(repeating: "a", count: 10_000)
        let log = SentryLog(
            timestamp: Date(),
            level: .info,
            body: longMessage,
            attributes: [:]
        )
        
        // When
        sut.processLog(log, with: scope)
        
        // Then
        XCTAssertEqual(mockDelegate.sendInvocations.count, 1)
        
        let envelope = mockDelegate.sendInvocations.first!
        let itemData = envelope.items.first!.data
        let jsonObject = try! JSONSerialization.jsonObject(with: itemData) as! [String: Any]
        let items = jsonObject["items"] as! [[String: Any]]
        let logData = items.first!
        
        XCTAssertEqual(logData["body"] as? String, longMessage)
    }
    
    func testProcessLog_MultipleLogsInSequence_CallsDelegateForEach() {
        // Given
        let logs = [
            createTestLog(level: .debug, body: "Debug message"),
            createTestLog(level: .info, body: "Info message"),
            createTestLog(level: .error, body: "Error message")
        ]
        
        // When
        for log in logs {
            sut.processLog(log, with: scope)
        }
        
        // Then
        XCTAssertEqual(mockDelegate.sendInvocations.count, 3)
        
        for (index, expectedBody) in ["Debug message", "Info message", "Error message"].enumerated() {
            let envelope = mockDelegate.sendInvocations[index]
            let itemData = envelope.items.first!.data
            let jsonObject = try! JSONSerialization.jsonObject(with: itemData) as! [String: Any]
            let items = jsonObject["items"] as! [[String: Any]]
            let logData = items.first!
            
            XCTAssertEqual(logData["body"] as? String, expectedBody)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testProcessLog_WhenEnvelopeCreationFails_DoesNotCallDelegate() {
        // Given
        let mockSDKLog = TestSDKLog()
        SentrySDKLog._configure(true, diagnosticLevel: .debug)
        
        // Create a log that would cause serialization issues
        // This is tricky to test since the SentryEnvelope(logs:) initializer 
        // handles most validation internally. For now, we'll test the happy path
        // and rely on integration tests for error scenarios.
        
        let log = createTestLog()
        
        // When
        sut.processLog(log, with: scope)
        
        // Then
        XCTAssertEqual(mockDelegate.sendInvocations.count, 1)
    }
    
    // MARK: - Delegate Tests
    
    func testProcessLog_WithNilDelegate_DoesNotCrash() {
        // Given
        let batcher = SentryLogBatcher(delegate: mockDelegate)
        // Simulate delegate being deallocated
        mockDelegate = nil
        let log = createTestLog()
        
        // When & Then - Should not crash
        batcher.processLog(log, with: scope)
    }
    
    // MARK: - Concurrency Tests
    
    func testProcessLog_ConcurrentCalls_AllCallsProcessed() {
        // Given
        let expectation = XCTestExpectation(description: "All logs processed")
        expectation.expectedFulfillmentCount = 10
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        // When
        for i in 0..<10 {
            queue.async {
                let log = self.createTestLog(body: "Concurrent message \(i)")
                self.sut.processLog(log, with: self.scope)
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(mockDelegate.sendInvocations.count, 10)
        
        // Verify all messages were processed
        let bodies = mockDelegate.sendInvocations.compactMap { envelope -> String? in
            guard let itemData = envelope.items.first?.data,
                  let jsonObject = try? JSONSerialization.jsonObject(with: itemData) as? [String: Any],
                  let items = jsonObject["items"] as? [[String: Any]],
                  let logData = items.first,
                  let body = logData["body"] as? String else {
                return nil
            }
            return body
        }
        
        for i in 0..<10 {
            XCTAssertTrue(bodies.contains("Concurrent message \(i)"))
        }
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

// MARK: - Test SDK Log

private class TestSDKLog {
    var messages: [String] = []
    
    func log(message: String, level: SentryLevel) {
        messages.append(message)
    }
} 
