@testable import Sentry
import XCTest

class SentryModifiableTests: XCTestCase {

    func testValue_whenSet_shouldMarkAsModified() {
        // -- Arrange --
        var sut = SentryModifiable(false)

        // -- Act --
        sut.value = true

        // -- Assert --
        XCTAssertTrue(sut.value)
        XCTAssertTrue(sut.isModified)
    }

    func testValue_whenResetToOriginalValue_shouldRemainModified() {
        // -- Arrange --
        var sut = SentryModifiable(false)
        sut.value = true

        // -- Act --
        sut.value = false

        // -- Assert --
        XCTAssertFalse(sut.value)
        XCTAssertTrue(sut.isModified)
    }

    func testInit_whenModifiedStateIsProvided_shouldUseModifiedState() {
        // -- Arrange --
        let sut = SentryModifiable(false, isModified: true)

        // -- Assert --
        XCTAssertFalse(sut.value)
        XCTAssertTrue(sut.isModified)
    }

    func testSetRecursivelyModifiedValue_whenSet_shouldMarkValueAndDescendantsAsModified() {
        // -- Arrange --
        var sut = SentryModifiable(TestRecursiveModifiable())

        // -- Act --
        sut.setRecursivelyModifiedValue(TestRecursiveModifiable())

        // -- Assert --
        XCTAssertTrue(sut.isModified)
        XCTAssertTrue(sut.value.child.isModified)
    }

    func testMarkRecursivelyAsModified_shouldMarkValueAndDescendantsAsModified() {
        // -- Arrange --
        var sut = SentryModifiable(TestRecursiveModifiable())

        // -- Act --
        sut.markRecursivelyAsModified()

        // -- Assert --
        XCTAssertTrue(sut.isModified)
        XCTAssertTrue(sut.value.child.isModified)
    }

    private struct TestRecursiveModifiable: SentryRecursiveModifiable {
        var child = SentryModifiable(false)

        mutating func markRecursivelyAsModified() {
            child.markAsModified()
        }
    }
}
