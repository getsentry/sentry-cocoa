@_spi(Private) import Sentry
import SentryTestUtils
import XCTest

final class SentryStrictTraceContinuationTests: XCTestCase {

    // MARK: - Options defaults

    func testOptions_strictTraceContinuation_defaultsFalse() {
        let options = Options()
        XCTAssertFalse(options.strictTraceContinuation)
    }

    func testOptions_orgId_defaultsNil() {
        let options = Options()
        XCTAssertNil(options.orgId)
    }

    // MARK: - effectiveOrgId

    func testEffectiveOrgId_whenExplicitOrgIdSet_shouldPreferExplicit() {
        // -- Arrange --
        let options = Options()
        options.dsn = "https://key@o123.ingest.sentry.io/456"
        options.orgId = "999"

        // -- Assert --
        XCTAssertEqual(options.effectiveOrgId, "999")
    }

    func testEffectiveOrgId_whenNoExplicitOrgId_shouldFallBackToDsn() {
        // -- Arrange --
        let options = Options()
        options.dsn = "https://key@o123.ingest.sentry.io/456"

        // -- Assert --
        XCTAssertEqual(options.effectiveOrgId, "123")
    }

    func testEffectiveOrgId_whenNoOrgIdConfigured_shouldReturnNil() {
        // -- Arrange --
        let options = Options()
        options.dsn = "https://key@sentry.io/456"

        // -- Assert --
        XCTAssertNil(options.effectiveOrgId)
    }

    func testEffectiveOrgId_whenEmptyExplicitOrgId_shouldFallBackToDsn() {
        // -- Arrange --
        let options = Options()
        options.dsn = "https://key@o123.ingest.sentry.io/456"
        options.orgId = ""

        // -- Assert --
        XCTAssertEqual(options.effectiveOrgId, "123")
    }

    // MARK: - shouldContinueTrace - strict=false

    func testShouldContinueTrace_whenStrictFalse_matchingOrgs_shouldContinue() {
        // -- Arrange --
        let options = makeOptions(dsnOrgId: "1", strict: false)

        // -- Act & Assert --
        XCTAssertTrue(
            SentryPropagationContext.shouldContinueTrace(options: options, baggageOrgId: "1")
        )
    }

    func testShouldContinueTrace_whenStrictFalse_baggageMissingOrg_shouldContinue() {
        // -- Arrange --
        let options = makeOptions(dsnOrgId: "1", strict: false)

        // -- Act & Assert --
        XCTAssertTrue(
            SentryPropagationContext.shouldContinueTrace(options: options, baggageOrgId: nil)
        )
    }

    func testShouldContinueTrace_whenStrictFalse_sdkMissingOrg_shouldContinue() {
        // -- Arrange --
        let options = makeOptions(dsnOrgId: nil, strict: false)

        // -- Act & Assert --
        XCTAssertTrue(
            SentryPropagationContext.shouldContinueTrace(options: options, baggageOrgId: "1")
        )
    }

    func testShouldContinueTrace_whenStrictFalse_bothMissingOrg_shouldContinue() {
        // -- Arrange --
        let options = makeOptions(dsnOrgId: nil, strict: false)

        // -- Act & Assert --
        XCTAssertTrue(
            SentryPropagationContext.shouldContinueTrace(options: options, baggageOrgId: nil)
        )
    }

    func testShouldContinueTrace_whenStrictFalse_mismatchedOrgs_shouldStartNewTrace() {
        // -- Arrange --
        let options = makeOptions(dsnOrgId: "2", strict: false)

        // -- Act & Assert --
        XCTAssertFalse(
            SentryPropagationContext.shouldContinueTrace(options: options, baggageOrgId: "1")
        )
    }

    // MARK: - shouldContinueTrace - strict=true

    func testShouldContinueTrace_whenStrictTrue_matchingOrgs_shouldContinue() {
        // -- Arrange --
        let options = makeOptions(dsnOrgId: "1", strict: true)

        // -- Act & Assert --
        XCTAssertTrue(
            SentryPropagationContext.shouldContinueTrace(options: options, baggageOrgId: "1")
        )
    }

    func testShouldContinueTrace_whenStrictTrue_baggageMissingOrg_shouldStartNewTrace() {
        // -- Arrange --
        let options = makeOptions(dsnOrgId: "1", strict: true)

        // -- Act & Assert --
        XCTAssertFalse(
            SentryPropagationContext.shouldContinueTrace(options: options, baggageOrgId: nil)
        )
    }

    func testShouldContinueTrace_whenStrictTrue_sdkMissingOrg_shouldStartNewTrace() {
        // -- Arrange --
        let options = makeOptions(dsnOrgId: nil, strict: true)

        // -- Act & Assert --
        XCTAssertFalse(
            SentryPropagationContext.shouldContinueTrace(options: options, baggageOrgId: "1")
        )
    }

    func testShouldContinueTrace_whenStrictTrue_bothMissingOrg_shouldContinue() {
        // -- Arrange --
        let options = makeOptions(dsnOrgId: nil, strict: true)

        // -- Act & Assert --
        XCTAssertTrue(
            SentryPropagationContext.shouldContinueTrace(options: options, baggageOrgId: nil)
        )
    }

    func testShouldContinueTrace_whenStrictTrue_mismatchedOrgs_shouldStartNewTrace() {
        // -- Arrange --
        let options = makeOptions(dsnOrgId: "2", strict: true)

        // -- Act & Assert --
        XCTAssertFalse(
            SentryPropagationContext.shouldContinueTrace(options: options, baggageOrgId: "1")
        )
    }

    // MARK: - Helpers

    private func makeOptions(dsnOrgId: String?, explicitOrgId: String? = nil, strict: Bool) -> Options {
        let options = Options()
        if let dsnOrgId = dsnOrgId {
            options.dsn = "https://key@o\(dsnOrgId).ingest.sentry.io/123"
        } else {
            options.dsn = "https://key@sentry.io/123"
        }
        options.orgId = explicitOrgId
        options.strictTraceContinuation = strict
        return options
    }
}
