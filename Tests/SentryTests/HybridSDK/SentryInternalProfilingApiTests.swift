@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

#if !(os(watchOS) || os(tvOS) || os(visionOS))

class SentryInternalProfilingApiTests: XCTestCase {

    private let mockDateProvider = TestCurrentDateProvider()
    private lazy var sut = SentryInternalProfilingApi(
        dependencies: MockProfilingDependencies(dateProvider: mockDateProvider)
    )

    // MARK: - start

    func testStart_whenDateProviderIsInjected_shouldReturnItsSystemTime() {
        // -- Arrange --
        mockDateProvider.advanceBy(nanoseconds: 123_456)
        let traceId = SentryId()
        defer { sut.discard(for: traceId) }

        // -- Act --
        let startTime = sut.start(for: traceId)

        // -- Assert --
        XCTAssertEqual(startTime, 123_456)
    }

    func testStart_withoutSDK_shouldReturnNonZero() {
        // Profiler uses kernel APIs and can start without the SDK.
        mockDateProvider.advanceBy(nanoseconds: 123_456)
        let traceId = SentryId()
        let startTime = sut.start(for: traceId)
        XCTAssertGreaterThan(startTime, 0)
        sut.discard(for: traceId)
    }

    func testStart_withoutSDK_multipleCalls_shouldReturnCurrentSystemTime() {
        // -- Arrange --
        mockDateProvider.advanceBy(nanoseconds: 123_456)
        let traceA = SentryId()
        let traceB = SentryId()
        defer {
            sut.discard(for: traceA)
            sut.discard(for: traceB)
        }

        // -- Act --
        let startA = sut.start(for: traceA)
        mockDateProvider.advanceBy(nanoseconds: 654_321)
        let startB = sut.start(for: traceB)

        // -- Assert --
        XCTAssertEqual(startA, 123_456)
        XCTAssertEqual(startB, 777_777)
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

private struct MockProfilingDependencies: DateProviderProvider {
    var dateProvider: SentryCurrentDateProvider
}

#endif
