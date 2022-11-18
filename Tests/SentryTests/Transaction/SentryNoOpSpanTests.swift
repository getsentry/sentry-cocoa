import Sentry
import XCTest

class SentryNoOpSpanTests: XCTestCase {

    func testIsOneInstance() {
        let first = SentryNoOpSpan.shared()
        let second = SentryNoOpSpan.shared()
        
        XCTAssertTrue(first === second)
    }
    
    func testStartChild_ReturnsSameInstance() {
        let sut = SentryNoOpSpan.shared()
        
        let child = sut.startChild(operation: "operation")
        XCTAssertNil(child.spanDescription)
        XCTAssertEqual("", child.operation)
        XCTAssertTrue(sut === child)
        
        let childWithDescription = sut.startChild(operation: "", description: "descr")
        
        XCTAssertTrue(sut === childWithDescription)
    }

    func testData_StaysNil() {
        let sut = SentryNoOpSpan.shared()
        XCTAssertNil(sut.data)
        sut.setData(value: "tet", key: "key")
        sut.setExtra(value: "tet", key: "key")
        sut.removeData(key: "any")
        XCTAssertNil(sut.data)
    }
    
    func testTagsStayEmpty_ReturnsEmptyDict() {
        let sut = SentryNoOpSpan.shared()
        XCTAssertTrue(sut.tags.isEmpty)
        sut.setTag(value: "value", key: "key")
        sut.removeTag(key: "any")
        XCTAssertTrue(sut.tags.isEmpty)
    }
    
    func testIsAlwaysNotFinished() {
        let sut = SentryNoOpSpan.shared()
        
        XCTAssertFalse(sut.isFinished)
        sut.finish()
        sut.finish(status: SentrySpanStatus.aborted)
        XCTAssertFalse(sut.isFinished)
    }
    
    func testSerialize_ReturnsEmptyDict() {
        XCTAssertTrue(SentryNoOpSpan.shared().serialize().isEmpty)
    }
    
    func testToTraceHeader() {
        let actual = SentryNoOpSpan.shared().toTraceHeader()
        
        XCTAssertEqual(SentryId.empty, actual.traceId)
        XCTAssertEqual(SpanId.empty, actual.spanId)
        XCTAssertEqual(SentrySampleDecision.undecided, actual.sampled)
    }
    
    func testContext() {
        let actual = SentryNoOpSpan.shared()
        
        XCTAssertEqual(SentryId.empty, actual.traceId)
        XCTAssertEqual(SpanId.empty, actual.spanId)
        XCTAssertEqual(SentrySampleDecision.undecided, actual.sampled)
    }

}
