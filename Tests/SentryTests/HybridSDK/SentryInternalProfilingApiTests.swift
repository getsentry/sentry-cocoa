@testable import Sentry
import XCTest

#if !(os(watchOS) || os(tvOS) || os(visionOS))

class SentryInternalProfilingApiTests: XCTestCase {

    private let sut = SentryInternalProfilingApi()

    // MARK: - start

    func testStart_withoutSDK_shouldReturnZero() {
        let startTime = sut.start(for: SentryId())
        XCTAssertEqual(startTime, 0)
    }

    // MARK: - collect

    func testCollect_withoutStart_shouldReturnNil() {
        let result = sut.collect(between: 0, and: 1, for: SentryId())
        XCTAssertNil(result)
    }

    // MARK: - discard

    func testDiscard_withoutStart_shouldNotCrash() {
        sut.discard(for: SentryId())
    }
}

#endif
