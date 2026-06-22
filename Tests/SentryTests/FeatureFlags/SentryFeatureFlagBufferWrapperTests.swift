@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

final class SentryFeatureFlagBufferWrapperTests: XCTestCase {

    func testScopeBuffer_whenAddingMoreThanLimit_shouldUseDropOldestLimit100() {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.scopeBuffer()

        // -- Act --
        for index in 0..<101 {
            sut.buffer.add(name: "flag-\(index)", value: true)
        }

        // -- Assert --
        XCTAssertEqual(sut.buffer.allEvaluations.count, 100)
        XCTAssertEqual(sut.buffer.allEvaluations.first?.flag, "flag-1")
        XCTAssertEqual(sut.buffer.allEvaluations.last?.flag, "flag-100")
    }

    func testScopeBuffer_whenLimitReached_shouldUpdateExistingFlagAsNewest() {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.scopeBuffer()
        for index in 0..<100 {
            sut.buffer.add(name: "flag-\(index)", value: true)
        }

        // -- Act --
        sut.buffer.add(name: "flag-0", value: false)

        // -- Assert --
        XCTAssertEqual(sut.buffer.allEvaluations.count, 100)
        XCTAssertEqual(sut.buffer.allEvaluations.first?.flag, "flag-1")
        XCTAssertEqual(sut.buffer.allEvaluations.last?.flag, "flag-0")
        XCTAssertEqual(sut.buffer.allEvaluations.last?.result, .boolean(false))
    }

    func testSpanBuffer_whenAddingMoreThanLimit_shouldUseRejectNewLimit10() {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.spanBuffer()

        // -- Act --
        for index in 0..<11 {
            sut.buffer.add(name: "flag-\(index)", value: true)
        }

        // -- Assert --
        XCTAssertEqual(sut.buffer.allEvaluations.count, 10)
        XCTAssertEqual(sut.buffer.allEvaluations.first?.flag, "flag-0")
        XCTAssertEqual(sut.buffer.allEvaluations.last?.flag, "flag-9")
        XCTAssertFalse(sut.buffer.allEvaluations.contains { $0.flag == "flag-10" })
    }

    func testSpanBuffer_whenLimitReached_shouldUpdateExistingFlagInPlace() {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.spanBuffer()
        for index in 0..<10 {
            sut.buffer.add(name: "flag-\(index)", value: true)
        }
        sut.buffer.add(name: "rejected", value: true)

        // -- Act --
        sut.buffer.add(name: "flag-0", value: false)

        // -- Assert --
        XCTAssertEqual(sut.buffer.allEvaluations.count, 10)
        XCTAssertEqual(sut.buffer.allEvaluations.first?.flag, "flag-0")
        XCTAssertEqual(sut.buffer.allEvaluations.first?.result, .boolean(false))
        XCTAssertFalse(sut.buffer.allEvaluations.contains { $0.flag == "rejected" })
    }

    func testCopyBuffer_whenMutatingCopy_shouldNotMutateOriginal() {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.scopeBuffer()
        sut.buffer.add(name: "first", value: true)

        // -- Act --
        let copy = sut.copyBuffer()
        copy.buffer.add(name: "second", value: false)

        // -- Assert --
        XCTAssertEqual(sut.buffer.allEvaluations.map(\.flag), ["first"])
        XCTAssertEqual(copy.buffer.allEvaluations.map(\.flag), ["first", "second"])
    }

    func testRemoveFeatureFlag_whenBufferHasFeatureFlag_shouldRemoveMatchingFlag() {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.scopeBuffer()
        sut.buffer.add(name: "checkout", value: true)
        sut.buffer.add(name: "search", value: false)

        // -- Act --
        sut.buffer.remove(name: "checkout")

        // -- Assert --
        XCTAssertEqual(sut.buffer.allEvaluations.map(\.flag), ["search"])
    }

    func testRemoveAll_whenBufferHasFeatureFlags_shouldClearEvaluations() {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.scopeBuffer()
        sut.buffer.add(name: "checkout", value: true)

        // -- Act --
        sut.removeAll()

        // -- Assert --
        XCTAssertTrue(sut.buffer.allEvaluations.isEmpty)
    }
}
