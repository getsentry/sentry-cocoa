@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

final class SentryFeatureFlagBufferWrapperTests: XCTestCase {

    func testScopeBuffer_whenAddingMoreThanLimit_shouldUseScopeBufferConfiguration() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.scopeBuffer()

        // -- Act --
        for index in 0..<101 {
            sut.add(name: "flag-\(index)", result: true)
        }

        // -- Assert --
        let values = try featureFlagValues(from: sut)
        XCTAssertEqual(values.count, 100)
        XCTAssertEqual(values.first?["flag"] as? String, "flag-1")
        XCTAssertEqual(values.last?["flag"] as? String, "flag-100")
    }

    func testSpanBuffer_whenAddingMoreThanLimit_shouldUseSpanBufferConfiguration() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.spanBuffer()

        // -- Act --
        for index in 0..<11 {
            sut.add(name: "flag-\(index)", result: true)
        }

        // -- Assert --
        let values = try featureFlagValues(from: sut)
        XCTAssertEqual(values.count, 10)
        XCTAssertEqual(values.first?["flag"] as? String, "flag-0")
        XCTAssertEqual(values.last?["flag"] as? String, "flag-9")
        XCTAssertFalse(values.contains { $0["flag"] as? String == "flag-10" })
    }

    func testSerializeForContext_whenFeatureFlagAdded_shouldReturnFlagsContext() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.scopeBuffer()

        // -- Act --
        sut.add(name: "checkout", result: true)

        // -- Assert --
        let values = try featureFlagValues(from: sut)
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.element(at: 0)?["flag"] as? String, "checkout")
        XCTAssertEqual(values.element(at: 0)?["result"] as? Bool, true)
    }

    func testSerializeForSpanData_whenFeatureFlagAdded_shouldReturnSpanData() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.spanBuffer()

        // -- Act --
        sut.add(name: "checkout", result: true)

        // -- Assert --
        let spanData = sut.serializeForSpanData()
        XCTAssertEqual(try XCTUnwrap(spanData["flag.evaluation.checkout"] as? Bool), true)
    }

    func testRemove_whenBufferHasFeatureFlag_shouldRemoveMatchingFlag() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.scopeBuffer()
        sut.add(name: "checkout", result: true)
        sut.add(name: "search", result: false)

        // -- Act --
        sut.remove(name: "checkout")

        // -- Assert --
        XCTAssertEqual(try featureFlagValues(from: sut).map { $0["flag"] as? String }, ["search"])
    }

    func testRemoveAll_whenBufferHasFeatureFlags_shouldClearEvaluations() {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.scopeBuffer()
        sut.add(name: "checkout", result: true)

        // -- Act --
        sut.removeAll()

        // -- Assert --
        XCTAssertNil(sut.serializeForContext())
        XCTAssertTrue(sut.serializeForSpanData().isEmpty)
    }

    func testCopyBuffer_whenMutatingCopy_shouldNotMutateOriginal() throws {
        // -- Arrange --
        let sut = SentryFeatureFlagBufferWrapper.scopeBuffer()
        sut.add(name: "first", result: true)

        // -- Act --
        let copy = sut.copyBuffer()
        copy.add(name: "second", result: false)

        // -- Assert --
        XCTAssertEqual(try featureFlagValues(from: sut).map { $0["flag"] as? String }, ["first"])
        XCTAssertEqual(try featureFlagValues(from: copy).map { $0["flag"] as? String }, ["first", "second"])
    }

    private func featureFlagValues(from wrapper: SentryFeatureFlagBufferWrapper) throws -> [[String: Any]] {
        let context = try XCTUnwrap(wrapper.serializeForContext())
        return try XCTUnwrap(context["values"] as? [[String: Any]])
    }
}
