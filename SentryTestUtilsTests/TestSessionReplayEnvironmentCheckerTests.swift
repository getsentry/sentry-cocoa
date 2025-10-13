import CwlPreconditionTesting
@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryTestUtils
import XCTest

class TestSessionReplayEnvironmentCheckerTests: XCTestCase {

    // MARK: - isReliable()

    func testGetAppValueString_withoutMockedValue_shouldFailWithPreconditionFailure() throws {
        // -- Arrange --
        let sut = TestSessionReplayEnvironmentChecker()
        // Don't mock any value for this key

        // -- Act --
        let e = catchBadInstruction {
            _ = sut.isReliable()
        }

        // -- Assert --
        XCTAssertNotNil(e)
    }

    func testIsReliable_withMockedValue_withSingleInvocations_shouldReturnMockedValue() throws {
        // -- Arrange --
        let sut = TestSessionReplayEnvironmentChecker()
        sut.mockIsReliableReturnValue(true)

        // -- Act --
        let result = sut.isReliable()

        // -- Assert --
        XCTAssertTrue(result, "isReliable() should return the same value as the one mocked")
    }

    func testIsReliable_withMockedValue_withMultipleInvocations_shouldReturnSameValue() throws {
        // -- Arrange --
        let sut = TestSessionReplayEnvironmentChecker()
        sut.mockIsReliableReturnValue(true)

        // -- Act --
        let result1 = sut.isReliable()
        let result2 = sut.isReliable()

        // -- Assert --
        XCTAssertTrue(result1)
        XCTAssertTrue(result2)
    }

    func testIsReliable_shouldRecordInvocations() throws {
        // -- Arrange --
        let sut = TestSessionReplayEnvironmentChecker()
        sut.mockIsReliableReturnValue(true)

        // -- Act --
        _ = sut.isReliable()
        _ = sut.isReliable()
        _ = sut.isReliable()

        // -- Assert --
        XCTAssertEqual(sut.isReliableInvocations.count, 3)
    }
}
