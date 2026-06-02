@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

final class SentryFeatureFlagBufferTests: XCTestCase {

    func testBoolValueConversion_whenValueIsBool_shouldReturnBooleanContent() {
        // -- Arrange --
        let value = true

        // -- Act --
        let actual = value.asSentryFeatureFlagValue

        // -- Assert --
        XCTAssertEqual(actual, .boolean(true))
    }

    func testEvaluation_whenSerializingForContext_shouldUseFlagsSchema() throws {
        // -- Arrange --
        let evaluation = SentryFeatureFlagEvaluation(flag: "checkout", result: .boolean(true))

        // -- Act --
        let actual = evaluation.serializeForContext()

        // -- Assert --
        XCTAssertEqual(actual["flag"] as? String, "checkout")
        XCTAssertEqual(try XCTUnwrap(actual["result"] as? Bool), true)
    }

    func testEvaluation_whenSerializingForSpanData_shouldUseFlagEvaluationKey() throws {
        // -- Arrange --
        let evaluation = SentryFeatureFlagEvaluation(flag: "checkout", result: .boolean(true))

        // -- Act --
        let actual = evaluation.serializeForSpanData()

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(actual["flag.evaluation.checkout"] as? Bool), true)
    }

    func testBuffer_whenSerializingForContext_shouldPreserveInsertionOrder() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer(maxSize: 3, overflowBehavior: .dropOldest)
        sut.add(name: "first", value: false)
        sut.add(name: "second", value: true)

        // -- Act --
        let actual = try XCTUnwrap(sut.serializeForContext())
        let values = try XCTUnwrap(actual["values"] as? [[String: Any]])

        // -- Assert --
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values.element(at: 0)?["flag"] as? String, "first")
        XCTAssertEqual(values.element(at: 0)?["result"] as? Bool, false)
        XCTAssertEqual(values.element(at: 1)?["flag"] as? String, "second")
        XCTAssertEqual(values.element(at: 1)?["result"] as? Bool, true)
    }

    func testBuffer_whenUpdatingExistingFlag_shouldRefreshAsNewest() {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer(maxSize: 3, overflowBehavior: .dropOldest)
        sut.add(name: "first", value: false)
        sut.add(name: "second", value: true)

        // -- Act --
        sut.add(name: "first", value: true)

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.map(\.flag), ["second", "first"])
        XCTAssertEqual(sut.allEvaluations.map(\.result), [.boolean(true), .boolean(true)])
    }

    func testBuffer_whenDropOldestOverflow_shouldRemoveOldestFlag() {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer(maxSize: 2, overflowBehavior: .dropOldest)
        sut.add(name: "first", value: true)
        sut.add(name: "second", value: true)

        // -- Act --
        sut.add(name: "third", value: false)

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.map(\.flag), ["second", "third"])
    }

    func testBuffer_whenMaxSizeIsZero_shouldStoreNothing() {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer(maxSize: 0, overflowBehavior: .dropOldest)

        // -- Act --
        sut.add(name: "first", value: true)

        // -- Assert --
        XCTAssertTrue(sut.allEvaluations.isEmpty)
        XCTAssertNil(sut.serializeForContext())
    }

    func testBuffer_whenRejectNewOverflow_shouldKeepExistingFlags() {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer(maxSize: 2, overflowBehavior: .rejectNew)
        sut.add(name: "first", value: true)
        sut.add(name: "second", value: true)

        // -- Act --
        sut.add(name: "third", value: false)

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.map(\.flag), ["first", "second"])
    }

    func testBuffer_whenRejectNewOverflow_shouldUpdateExistingFlag() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer(maxSize: 2, overflowBehavior: .rejectNew)
        sut.add(name: "first", value: true)
        sut.add(name: "second", value: true)
        sut.add(name: "third", value: false)

        // -- Act --
        sut.add(name: "first", value: false)

        // -- Assert --
        let spanData = sut.serializeForSpanData()
        XCTAssertEqual(spanData.count, 2)
        XCTAssertEqual(try XCTUnwrap(spanData["flag.evaluation.first"] as? Bool), false)
        XCTAssertEqual(try XCTUnwrap(spanData["flag.evaluation.second"] as? Bool), true)
    }

    func testCopyBuffer_whenMutatingCopy_shouldNotMutateOriginal() {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer(maxSize: 3, overflowBehavior: .dropOldest)
        sut.add(name: "first", value: true)
        let copy = sut.copyBuffer()

        // -- Act --
        copy.add(name: "second", value: false)

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.map(\.flag), ["first"])
        XCTAssertEqual(copy.allEvaluations.map(\.flag), ["first", "second"])
    }
}
