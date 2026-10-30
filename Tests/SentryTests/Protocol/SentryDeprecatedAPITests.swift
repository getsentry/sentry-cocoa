#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

class SentryDeprecatedAPITests: XCTestCase {

    func testDomain_shouldMatchErrorDomainLiteral() {
        XCTAssertEqual(SentryError.domain, "SentryErrorDomain")
    }

    func testNsError_withDescription_shouldUseCaseCodeAndDomain() {
        let error = SentryError.fileIO.nsError(description: "disk full")

        XCTAssertEqual(error.domain, "SentryErrorDomain")
        XCTAssertEqual(error.code, SentryError.fileIO.rawValue)
        XCTAssertEqual(error.localizedDescription, "disk full")
    }

    func testSpanStatusName_shouldMatchWireLiteral() {
        let names: [(SentrySpanStatus, String)] = [
            (.undefined, "undefined"),
            (.ok, "ok"),
            (.deadlineExceeded, "deadline_exceeded"),
            (.unauthenticated, "unauthenticated"),
            (.permissionDenied, "permission_denied"),
            (.notFound, "not_found"),
            (.resourceExhausted, "resource_exhausted"),
            (.invalidArgument, "invalid_argument"),
            (.unimplemented, "unimplemented"),
            (.unavailable, "unavailable"),
            (.internalError, "internal_error"),
            (.unknownError, "unknown_error"),
            (.cancelled, "cancelled"),
            (.alreadyExists, "already_exists"),
            (.failedPrecondition, "failed_precondition"),
            (.aborted, "aborted"),
            (.outOfRange, "out_of_range"),
            (.dataLoss, "data_loss")
        ]

        for (status, wireName) in names {
            XCTAssertEqual(status.name, wireName)
        }
    }

    func testHttpHeaderFields_shouldMatchWireLiterals() {
        XCTAssertEqual(Baggage.httpHeaderField, "baggage")
        XCTAssertEqual(TraceHeader.httpHeaderField, "sentry-trace")
    }
}
