@_spi(Private) @testable import Sentry
import XCTest

final class SentryEnvelopeItemTypesTests: XCTestCase {

    // MARK: - Event Type Tests
    
    func testEvent_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.event, "event")
    }
    
    // MARK: - Session Type Tests
    
    func testSession_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.session, "session")
    }
    
    // MARK: - Feedback Type Tests
    
    func testFeedback_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.feedback, "feedback")
    }
    
    // MARK: - Transaction Type Tests
    
    func testTransaction_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.transaction, "transaction")
    }
    
    // MARK: - Attachment Type Tests
    
    func testAttachment_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.attachment, "attachment")
    }
    
    // MARK: - Client Report Type Tests
    
    func testClientReport_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.clientReport, "client_report")
    }
    
    // MARK: - Profile Type Tests
    
    func testProfile_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.profile, "profile")
    }
    
    // MARK: - Replay Video Type Tests
    
    func testReplayVideo_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.replayVideo, "replay_video")
    }
    
    // MARK: - Statsd Type Tests
    
    func testStatsd_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.statsd, "statsd")
    }
    
    // MARK: - Profile Chunk Type Tests
    
    func testProfileChunk_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.profileChunk, "profile_chunk")
    }
    
    // MARK: - Log Type Tests
    
    func testLog_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.log, "log")
    }
    
    // MARK: - Trace Metric Type Tests
    
    func testTraceMetric_shouldReturnCorrectString() {
        // -- Act & Assert --
        XCTAssertEqual(SentryEnvelopeItemTypes.traceMetric, "trace_metric")
    }
    
    // MARK: - All Types Tests
    
    func testAllTypes_shouldHaveUniqueValues() {
        // -- Arrange --
        let allTypes = [
            SentryEnvelopeItemTypes.event,
            SentryEnvelopeItemTypes.session,
            SentryEnvelopeItemTypes.feedback,
            SentryEnvelopeItemTypes.transaction,
            SentryEnvelopeItemTypes.attachment,
            SentryEnvelopeItemTypes.clientReport,
            SentryEnvelopeItemTypes.profile,
            SentryEnvelopeItemTypes.replayVideo,
            SentryEnvelopeItemTypes.statsd,
            SentryEnvelopeItemTypes.profileChunk,
            SentryEnvelopeItemTypes.log,
            SentryEnvelopeItemTypes.traceMetric
        ]
        
        // -- Act --
        let uniqueTypes = Set(allTypes)
        
        // -- Assert --
        XCTAssertEqual(allTypes.count, uniqueTypes.count, "All envelope item types should have unique string values")
    }
    
    func testAllTypes_shouldNotBeEmpty() {
        // -- Arrange --
        let allTypes = [
            SentryEnvelopeItemTypes.event,
            SentryEnvelopeItemTypes.session,
            SentryEnvelopeItemTypes.feedback,
            SentryEnvelopeItemTypes.transaction,
            SentryEnvelopeItemTypes.attachment,
            SentryEnvelopeItemTypes.clientReport,
            SentryEnvelopeItemTypes.profile,
            SentryEnvelopeItemTypes.replayVideo,
            SentryEnvelopeItemTypes.statsd,
            SentryEnvelopeItemTypes.profileChunk,
            SentryEnvelopeItemTypes.log,
            SentryEnvelopeItemTypes.traceMetric
        ]
        
        // -- Act & Assert --
        for type in allTypes {
            XCTAssertFalse(type.isEmpty, "Envelope item type '\(type)' should not be empty")
        }
    }
}
