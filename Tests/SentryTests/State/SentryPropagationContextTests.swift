import SentryTestUtils
import XCTest

final class SentryPropagationContextTests: XCTestCase {
    
    func testGetTraceContextWithOptionsAndSegment() throws {
        let options = Options()
        options.dsn = TestConstants.realDSN
    
        let sut = SentryPropagationContext()
        let traceContext = try XCTUnwrap(sut.getTraceContext(options: options, userSegment: "segment"))
        
        XCTAssertEqual(options.parsedDsn?.url.user, traceContext.publicKey)
        XCTAssertEqual(sut.traceId, traceContext.traceId)
        XCTAssertEqual(options.releaseName, traceContext.releaseName)
        XCTAssertEqual(options.environment, traceContext.environment)
        XCTAssertNil(traceContext.transaction)
        XCTAssertEqual("segment", traceContext.userSegment)
        XCTAssertNil(traceContext.sampleRate)
        XCTAssertNil(traceContext.sampled)
    }
    
    func testGetTraceContextWithOptionsOnly() throws {
        let options = Options()
        options.dsn = TestConstants.realDSN
    
        let sut = SentryPropagationContext()
        let traceContext = try XCTUnwrap(sut.getTraceContext(options: options, userSegment: nil))
        
        XCTAssertEqual(options.parsedDsn?.url.user, traceContext.publicKey)
        XCTAssertEqual(sut.traceId, traceContext.traceId)
        XCTAssertEqual(options.releaseName, traceContext.releaseName)
        XCTAssertEqual(options.environment, traceContext.environment)
        XCTAssertNil(traceContext.transaction)
        XCTAssertNil(traceContext.userSegment)
        XCTAssertNil(traceContext.sampleRate)
        XCTAssertNil(traceContext.sampled)
    }

}
