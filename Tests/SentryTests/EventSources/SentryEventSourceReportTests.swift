#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryEventSourceReportTests: XCTestCase {
    func testIsWatchdogTermination_whenCrashHasWatchdogTerminationReason_shouldBeTrue() {
        // -- Arrange --
        let runEnd = SentryEventSourceReport.RunEnd.crash(terminationReason: "Namespace SPRINGBOARD, Code 0x8BADF00D")

        // -- Act & Assert --
        XCTAssertTrue(runEnd.isWatchdogTermination)
    }

    func testIsWatchdogTermination_whenCrashHasOtherTerminationReason_shouldBeFalse() {
        // -- Arrange --
        let runEnd = SentryEventSourceReport.RunEnd.crash(terminationReason: "Namespace SIGNAL, Code 0xb")

        // -- Act & Assert --
        XCTAssertFalse(runEnd.isWatchdogTermination)
    }

    func testIsWatchdogTermination_whenCrashHasNoTerminationReason_shouldBeFalse() {
        // -- Arrange --
        let runEnd = SentryEventSourceReport.RunEnd.crash(terminationReason: nil)

        // -- Act & Assert --
        XCTAssertFalse(runEnd.isWatchdogTermination)
    }

    func testIsWatchdogTermination_whenMemoryTermination_shouldBeTrue() {
        // -- Arrange --
        let runEnd = SentryEventSourceReport.RunEnd.memoryTermination

        // -- Act & Assert --
        XCTAssertTrue(runEnd.isWatchdogTermination)
    }
}
