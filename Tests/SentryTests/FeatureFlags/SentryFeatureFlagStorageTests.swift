@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

final class SentryFeatureFlagStorageTests: XCTestCase {

    func testScopeStorage_whenAddingMoreThanLimit_shouldUseDropOldestLimit100() {
        // -- Arrange --
        let sut = SentryFeatureFlagStorage.scopeStorage()

        // -- Act --
        for index in 0..<101 {
            sut.addFeatureFlag(name: "flag-\(index)", result: true)
        }

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.count, 100)
        XCTAssertEqual(sut.allEvaluations.first?.flag, "flag-1")
        XCTAssertEqual(sut.allEvaluations.last?.flag, "flag-100")
    }

    func testScopeStorage_whenLimitReached_shouldUpdateExistingFlagAsNewest() {
        // -- Arrange --
        let sut = SentryFeatureFlagStorage.scopeStorage()
        for index in 0..<100 {
            sut.addFeatureFlag(name: "flag-\(index)", result: true)
        }

        // -- Act --
        sut.addFeatureFlag(name: "flag-0", result: false)

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.count, 100)
        XCTAssertEqual(sut.allEvaluations.first?.flag, "flag-1")
        XCTAssertEqual(sut.allEvaluations.last?.flag, "flag-0")
        XCTAssertEqual(sut.allEvaluations.last?.result, .boolean(false))
    }

    func testSpanStorage_whenAddingMoreThanLimit_shouldUseRejectNewLimit10() {
        // -- Arrange --
        let sut = SentryFeatureFlagStorage.spanStorage()

        // -- Act --
        for index in 0..<11 {
            sut.addFeatureFlag(name: "flag-\(index)", result: true)
        }

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.count, 10)
        XCTAssertEqual(sut.allEvaluations.first?.flag, "flag-0")
        XCTAssertEqual(sut.allEvaluations.last?.flag, "flag-9")
        XCTAssertFalse(sut.allEvaluations.contains { $0.flag == "flag-10" })
    }

    func testSpanStorage_whenLimitReached_shouldUpdateExistingFlagInPlace() {
        // -- Arrange --
        let sut = SentryFeatureFlagStorage.spanStorage()
        for index in 0..<10 {
            sut.addFeatureFlag(name: "flag-\(index)", result: true)
        }
        sut.addFeatureFlag(name: "rejected", result: true)

        // -- Act --
        sut.addFeatureFlag(name: "flag-0", result: false)

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.count, 10)
        XCTAssertEqual(sut.allEvaluations.first?.flag, "flag-0")
        XCTAssertEqual(sut.allEvaluations.first?.result, .boolean(false))
        XCTAssertFalse(sut.allEvaluations.contains { $0.flag == "rejected" })
    }

    func testCopyStorage_whenMutatingCopy_shouldNotMutateOriginal() {
        // -- Arrange --
        let sut = SentryFeatureFlagStorage.scopeStorage()
        sut.addFeatureFlag(name: "first", result: true)

        // -- Act --
        let copy = sut.copyStorage()
        copy.addFeatureFlag(name: "second", result: false)

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.map(\.flag), ["first"])
        XCTAssertEqual(copy.allEvaluations.map(\.flag), ["first", "second"])
    }

    func testRemoveFeatureFlag_whenStorageHasFeatureFlag_shouldRemoveMatchingFlag() {
        // -- Arrange --
        let sut = SentryFeatureFlagStorage.scopeStorage()
        sut.addFeatureFlag(name: "checkout", result: true)
        sut.addFeatureFlag(name: "search", result: false)

        // -- Act --
        sut.removeFeatureFlag(name: "checkout")

        // -- Assert --
        XCTAssertEqual(sut.allEvaluations.map(\.flag), ["search"])
    }

    func testRemoveAll_whenStorageHasFeatureFlags_shouldClearEvaluations() {
        // -- Arrange --
        let sut = SentryFeatureFlagStorage.scopeStorage()
        sut.addFeatureFlag(name: "checkout", result: true)

        // -- Act --
        sut.removeAll()

        // -- Assert --
        XCTAssertTrue(sut.allEvaluations.isEmpty)
    }
}
