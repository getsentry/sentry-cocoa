@testable import Sentry
import XCTest

#if !(os(watchOS) || os(tvOS) || os(visionOS))

class SentryInternalProfilingApiTests: XCTestCase {

    private let sut = SentryInternalProfilingApi()

    // MARK: - start

    func testStart_withoutSDK_shouldReturnNonZero() {
        // Profiler uses kernel APIs and can start without the SDK.
        let traceId = SentryId()
        let startTime = sut.start(for: traceId)
        XCTAssertGreaterThan(startTime, 0)
        sut.discard(for: traceId)
    }

    func testStart_withoutSDK_multipleCalls_shouldAllReturnNonZero() {
        let traceA = SentryId()
        let traceB = SentryId()
        let startA = sut.start(for: traceA)
        let startB = sut.start(for: traceB)
        XCTAssertGreaterThan(startA, 0)
        XCTAssertGreaterThan(startB, 0)
        sut.discard(for: traceA)
        sut.discard(for: traceB)
    }

    // MARK: - collect

    func testCollect_withoutStart_shouldReturnNil() {
        let result = sut.collect(between: 0, and: 1, for: SentryId())
        XCTAssertNil(result)
    }

    func testCollect_withoutSDK_shouldReturnNil() {
        let traceId = SentryId()
        _ = sut.start(for: traceId)
        let result = sut.collect(between: 0, and: 1_000_000, for: traceId)
        XCTAssertNil(result)
    }

    func testCollect_withUnknownTraceId_shouldReturnNil() {
        let result = sut.collect(between: 0, and: 1_000_000, for: SentryId())
        XCTAssertNil(result)
    }

    // MARK: - discard

    func testDiscard_withoutStart_shouldNotCrash() {
        sut.discard(for: SentryId())
    }

    func testDiscard_withoutSDK_shouldNotCrash() {
        let traceId = SentryId()
        _ = sut.start(for: traceId)
        sut.discard(for: traceId)
    }

    func testDiscard_withUnknownTraceId_shouldNotCrash() {
        sut.discard(for: SentryId())
    }
}

#endif
