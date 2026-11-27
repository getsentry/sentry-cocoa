@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

final class SentryFeatureFlagBufferTests: XCTestCase {

    func testBuffer_whenAddingFeatureFlagValue_shouldSerializeConvertedValue() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer(maxSize: 3, overflowBehavior: .dropOldest)

        // -- Act --
        sut.add(name: "checkout", value: TestFeatureFlagValue(value: true))

        // -- Assert --
        let context = try XCTUnwrap(sut.serializeForContext())
        let values = try XCTUnwrap(context["values"] as? [[String: Any]])
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.element(at: 0)?["flag"] as? String, "checkout")
        XCTAssertEqual(values.element(at: 0)?["result"] as? Bool, true)
    }

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
        XCTAssertEqual(sut.allEvaluations.map(\.flag), ["first", "second"])
        XCTAssertEqual(try XCTUnwrap(spanData["flag.evaluation.first"] as? Bool), false)
        XCTAssertEqual(try XCTUnwrap(spanData["flag.evaluation.second"] as? Bool), true)
    }

    func testScopeBuffer_whenNoMaxSizeGiven_shouldRetainOneHundredEvaluations() {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer.scopeBuffer()

        // -- Act --
        for index in 0..<150 {
            sut.add(name: "flag-\(index)", value: true)
        }

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.count, 100)
    }

    func testScopeBuffer_whenMaxSizeGiven_shouldRetainMostRecentEvaluations() {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer.scopeBuffer(maxSize: 5)

        // -- Act --
        for index in 0..<10 {
            sut.add(name: "flag-\(index)", value: true)
        }

        // -- Assert --
        XCTAssertEqual(
            sut.allEvaluations.map(\.flag),
            ["flag-5", "flag-6", "flag-7", "flag-8", "flag-9"]
        )
    }

    func testScopeBuffer_whenMaxSizeIsZero_shouldRetainNothing() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer.scopeBuffer(maxSize: 0)

        // -- Act --
        sut.add(name: "first", value: true)

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.count, 0)
        XCTAssertNil(sut.serializeForContext())
    }

    func testScopeBuffer_whenMaxSizeIsLarge_shouldRetainAllEvaluations() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer.scopeBuffer(maxSize: 2_000)

        // -- Act --
        for index in 0..<2_000 {
            sut.add(name: "flag-\(index)", value: true)
        }

        // -- Assert --
        let context = try XCTUnwrap(sut.serializeForContext())
        let values = try XCTUnwrap(context["values"] as? [[String: Any]])
        XCTAssertEqual(values.count, 2_000)
    }

    func testScopeBuffer_whenReevaluatingExistingFlag_shouldNotConsumeAnotherSlot() {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer.scopeBuffer(maxSize: 2)
        sut.add(name: "first", value: true)
        sut.add(name: "second", value: true)

        // -- Act --
        sut.add(name: "first", value: false)

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.map(\.flag), ["second", "first"])
        XCTAssertEqual(sut.allEvaluations.last?.result, .boolean(false))
    }

    func testCopy_whenBufferHasCustomMaxSize_shouldPreserveMaxSize() {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer.scopeBuffer(maxSize: 2)
        sut.add(name: "first", value: true)
        sut.add(name: "second", value: true)

        // -- Act --
        let copy = sut.copy()
        copy.add(name: "third", value: true)

        // -- Assert --
        XCTAssertEqual(copy.allEvaluations.map(\.flag), ["second", "third"])
    }

    func testCopy_whenMutatingCopy_shouldNotMutateOriginal() {
        // -- Arrange --
        let sut = SentryFeatureFlagBuffer(maxSize: 3, overflowBehavior: .dropOldest)
        sut.add(name: "first", value: true)
        let copy = sut.copy()

        // -- Act --
        copy.add(name: "second", value: false)

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.map(\.flag), ["first"])
        XCTAssertEqual(copy.allEvaluations.map(\.flag), ["first", "second"])
    }
}

private struct TestFeatureFlagValue: SentryFeatureFlagValue {
    let value: Bool

    var asSentryFeatureFlagValue: SentryFeatureFlagValueContent {
        .boolean(value)
    }
}
