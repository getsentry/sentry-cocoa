@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)

final class SentryMXRunIdThreadCrumbTests: XCTestCase {

    func testSpell_whenMessageHasHexDigits_shouldReturnOneAddressPerDigit() throws {
        // -- Act --
        let addresses = try XCTUnwrap(SentryMXRunIdThreadCrumb.spell("0a1B"))

        // -- Assert --
        XCTAssertEqual(addresses.count, 4)
        XCTAssertFalse(addresses.contains(0))
    }

    func testSpell_whenMessageRepeatsADigit_shouldReturnTheSameFrameForIt() throws {
        // -- Act --
        let addresses = try XCTUnwrap(SentryMXRunIdThreadCrumb.spell("AABA"))

        // -- Assert --
        // Each digit is its own function with one call site, so the same digit returns to the
        // same address wherever it is in the message, and different digits to different ones.
        XCTAssertEqual(addresses.count, 4)
        let first = try XCTUnwrap(addresses.element(at: 0))
        XCTAssertEqual(first, try XCTUnwrap(addresses.element(at: 1)))
        XCTAssertEqual(first, try XCTUnwrap(addresses.element(at: 3)))
        XCTAssertNotEqual(first, try XCTUnwrap(addresses.element(at: 2)))
    }

    func testSpell_whenMessageMixesCase_shouldSpellCaseInsensitively() throws {
        // -- Act --
        let addresses = try XCTUnwrap(SentryMXRunIdThreadCrumb.spell("aA"))

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(addresses.element(at: 0)), try XCTUnwrap(addresses.element(at: 1)))
    }

    func testSpell_whenMessageHasOtherCharacters_shouldSkipThem() throws {
        // -- Act --
        let withHyphens = try XCTUnwrap(SentryMXRunIdThreadCrumb.spell("1-2-3"))
        let plain = try XCTUnwrap(SentryMXRunIdThreadCrumb.spell("123"))

        // -- Assert --
        XCTAssertEqual(withHyphens, plain)
    }

    func testSpell_whenMessageHasNoHexDigits_shouldReturnNil() {
        // -- Act & Assert --
        XCTAssertNil(SentryMXRunIdThreadCrumb.spell("xyz-"))
        XCTAssertNil(SentryMXRunIdThreadCrumb.spell(""))
    }

    func testSpell_whenMessageIsARunId_shouldReturnOneAddressPerHexDigit() throws {
        // -- Act --
        let addresses = try XCTUnwrap(SentryMXRunIdThreadCrumb.spell(UUID().uuidString))

        // -- Assert --
        XCTAssertEqual(addresses.count, 32)
    }

    func testSpell_whenMessageIsLongerThanTheMaximum_shouldSpellTheMaximum() throws {
        // -- Act --
        let addresses = try XCTUnwrap(SentryMXRunIdThreadCrumb.spell(String(repeating: "F", count: 100)))

        // -- Assert --
        // SENTRY_THREADCRUMB_MAX_LENGTH
        XCTAssertEqual(addresses.count, 64)
    }

    func testPark_whenCalledAgainWithTheSameRunId_shouldReturnTheSameAddresses() throws {
        // -- Arrange --
        let sut = SentryMXRunIdThreadCrumb()

        // -- Act --
        let first = try XCTUnwrap(sut.park(runId: "ABC"))
        let second = sut.park(runId: "ABC")

        // -- Assert --
        XCTAssertEqual(first, second)
    }

    func testPark_whenCalledWithAnotherRunId_shouldReturnNil() throws {
        // -- Arrange --
        let sut = SentryMXRunIdThreadCrumb()
        _ = try XCTUnwrap(sut.park(runId: "ABC"))

        // -- Act & Assert --
        XCTAssertNil(sut.park(runId: "DEF"))
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
