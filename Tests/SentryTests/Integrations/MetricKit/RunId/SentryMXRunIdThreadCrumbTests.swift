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
        let addresses = try SentryMXRunIdThreadCrumb.spell("0a1B")

        // -- Assert --
        XCTAssertEqual(addresses.count, 4)
        XCTAssertFalse(addresses.contains(0))
    }

    func testSpell_whenMessageRepeatsADigit_shouldReturnTheSameFrameForIt() throws {
        // -- Act --
        let addresses = try SentryMXRunIdThreadCrumb.spell("AABA")

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
        let addresses = try SentryMXRunIdThreadCrumb.spell("aA")

        // -- Assert --
        XCTAssertEqual(try XCTUnwrap(addresses.element(at: 0)), try XCTUnwrap(addresses.element(at: 1)))
    }

    func testSpell_whenMessageHasOtherCharacters_shouldSkipThem() throws {
        // -- Act --
        let withHyphens = try SentryMXRunIdThreadCrumb.spell("1-2-3")
        let plain = try SentryMXRunIdThreadCrumb.spell("123")

        // -- Assert --
        XCTAssertEqual(withHyphens, plain)
    }

    func testSpell_whenMessageHasNoHexDigits_shouldReturnNil() {
        // -- Act & Assert --
        XCTAssertThrowsError(try SentryMXRunIdThreadCrumb.spell("xyz-")) { error in
            XCTAssertEqual(error as? SentryMXRunIdThreadCrumb.ParkError, .notSpelled)
        }
        XCTAssertThrowsError(try SentryMXRunIdThreadCrumb.spell("")) { error in
            XCTAssertEqual(error as? SentryMXRunIdThreadCrumb.ParkError, .notSpelled)
        }
    }

    func testSpell_whenMessageIsARunId_shouldReturnOneAddressPerHexDigit() throws {
        // -- Act --
        let addresses = try SentryMXRunIdThreadCrumb.spell(UUID().uuidString)

        // -- Assert --
        XCTAssertEqual(addresses.count, 32)
    }

    func testSpell_whenMessageIsLongerThanTheMaximum_shouldSpellTheMaximum() throws {
        // -- Act --
        let addresses = try SentryMXRunIdThreadCrumb.spell(String(repeating: "F", count: 100))

        // -- Assert --
        // SENTRY_THREADCRUMB_MAX_LENGTH
        XCTAssertEqual(addresses.count, 64)
    }

    func testPark_whenCalledAgainWithTheSameRunId_shouldReturnTheSameAddresses() throws {
        // -- Arrange --
        let sut = SentryMXRunIdThreadCrumb()

        // -- Act --
        let first = try sut.park(runId: SentryCurrentRun.ID(rawValue: "ABC"))
        let second = try sut.park(runId: SentryCurrentRun.ID(rawValue: "ABC"))

        // -- Assert --
        XCTAssertEqual(first, second)
    }

    func testPark_whenCalledWithAnotherRunId_shouldThrowParkedForAnotherRun() throws {
        // -- Arrange --
        let sut = SentryMXRunIdThreadCrumb()
        _ = try sut.park(runId: SentryCurrentRun.ID(rawValue: "ABC"))

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.park(runId: SentryCurrentRun.ID(rawValue: "DEF"))) { error in
            XCTAssertEqual(
                error as? SentryMXRunIdThreadCrumb.ParkError,
                .parkedForAnotherRun(SentryCurrentRun.ID(rawValue: "ABC"))
            )
        }
    }

    func testPark_whenAnEarlierAttemptFailed_shouldNotTryAgain() {
        // -- Arrange --
        let sut = SentryMXRunIdThreadCrumb()
        // A run ID without a hexadecimal digit can't be spelled, which stands in for a crumb whose
        // thread didn't spell in time and may still be parked.
        XCTAssertThrowsError(try sut.park(runId: SentryCurrentRun.ID(rawValue: "xyz-"))) { error in
            XCTAssertEqual(error as? SentryMXRunIdThreadCrumb.ParkError, .notSpelled)
        }

        // -- Act & Assert --
        XCTAssertThrowsError(
            try sut.park(runId: SentryCurrentRun.ID(rawValue: "ABC")),
            "A failed attempt must not lead to a second thread"
        ) { error in
            XCTAssertEqual(error as? SentryMXRunIdThreadCrumb.ParkError, .earlierAttemptFailed)
        }
    }

    func testPark_whenAnotherCallIsSpelling_shouldWaitAndReturnItsAddresses() {
        // -- Arrange --
        let spelling = expectation(description: "The first call is spelling")
        let finishSpelling = DispatchSemaphore(value: 0)
        let spellCount = SentryMutex<Int>(0)
        let sut = SentryMXRunIdThreadCrumb(spell: { _ in
            spellCount.withLock { $0 += 1 }
            spelling.fulfill()
            finishSpelling.wait()
            return [1, 2, 3]
        })
        let runId = SentryCurrentRun.ID(rawValue: "ABC")
        let results = SentryMutex<[[UInt64]]>([])
        let parked = expectation(description: "Both calls returned")
        parked.expectedFulfillmentCount = 2
        let park = {
            do {
                let addresses = try sut.park(runId: runId)
                results.withLock { $0.append(addresses) }
            } catch {
                XCTFail("Parking should succeed, but threw \(error)")
            }
            parked.fulfill()
        }

        // -- Act --
        DispatchQueue.global().async(execute: park)
        wait(for: [spelling], timeout: 5)
        DispatchQueue.global().async(execute: park)
        finishSpelling.signal()

        // -- Assert --
        wait(for: [parked], timeout: 5)
        XCTAssertEqual(results.withLock { $0 }, [[1, 2, 3], [1, 2, 3]])
        XCTAssertEqual(spellCount.withLock { $0 }, 1, "The overlapping call must not park a second thread")
    }

    func testPark_whenAnotherCallIsSpellingAndFails_shouldThrowEarlierAttemptFailed() {
        // -- Arrange --
        let spelling = expectation(description: "The first call is spelling")
        let finishSpelling = DispatchSemaphore(value: 0)
        let sut = SentryMXRunIdThreadCrumb(spell: { _ in
            spelling.fulfill()
            finishSpelling.wait()
            throw SentryMXRunIdThreadCrumb.ParkError.notSpelled
        })
        let runId = SentryCurrentRun.ID(rawValue: "ABC")
        let errors = SentryMutex<[String: SentryMXRunIdThreadCrumb.ParkError]>([:])
        let threw = expectation(description: "Both calls threw")
        threw.expectedFulfillmentCount = 2
        let park = { (caller: String) in
            do {
                _ = try sut.park(runId: runId)
                XCTFail("Parking should throw for the \(caller) call")
            } catch {
                errors.withLock { $0[caller] = error as? SentryMXRunIdThreadCrumb.ParkError }
            }
            threw.fulfill()
        }

        // -- Act --
        DispatchQueue.global().async { park("spelling") }
        wait(for: [spelling], timeout: 5)
        DispatchQueue.global().async { park("overlapping") }
        finishSpelling.signal()

        // -- Assert --
        wait(for: [threw], timeout: 5)
        XCTAssertEqual(errors.withLock { $0 }, ["spelling": .notSpelled, "overlapping": .earlierAttemptFailed])
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
