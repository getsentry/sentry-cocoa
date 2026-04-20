@_spi(Private) import Sentry
import XCTest

final class SentryDsnOrgIdTests: XCTestCase {

    func testOrgId_whenHostHasOrgPrefix_shouldExtractOrgId() throws {
        // -- Arrange --
        let dsn = try SentryDsn(string: "https://key@o123.ingest.sentry.io/456")

        // -- Assert --
        XCTAssertEqual(dsn.orgId, "123")
    }

    func testOrgId_whenHostHasSingleDigitOrgPrefix_shouldExtractOrgId() throws {
        // -- Arrange --
        let dsn = try SentryDsn(string: "https://key@o1.ingest.us.sentry.io/456")

        // -- Assert --
        XCTAssertEqual(dsn.orgId, "1")
    }

    func testOrgId_whenHostHasLargeOrgId_shouldExtractOrgId() throws {
        // -- Arrange --
        let dsn = try SentryDsn(string: "https://key@o447951.ingest.sentry.io/5428557")

        // -- Assert --
        XCTAssertEqual(dsn.orgId, "447951")
    }

    func testOrgId_whenHostHasNoOrgPrefix_shouldReturnNil() throws {
        // -- Arrange --
        let dsn = try SentryDsn(string: "https://key@sentry.io/456")

        // -- Assert --
        XCTAssertNil(dsn.orgId)
    }

    func testOrgId_whenHostIsLocalhost_shouldReturnNil() throws {
        // -- Arrange --
        let dsn = try SentryDsn(string: "http://key@localhost:9000/456")

        // -- Assert --
        XCTAssertNil(dsn.orgId)
    }

    func testOrgId_whenHostHasNonNumericOrgPrefix_shouldReturnNil() throws {
        // -- Arrange --
        let dsn = try SentryDsn(string: "https://key@oabc.ingest.sentry.io/456")

        // -- Assert --
        XCTAssertNil(dsn.orgId)
    }

    func testOrgId_whenHostIsCustomDomain_shouldReturnNil() throws {
        // -- Arrange --
        let dsn = try SentryDsn(string: "https://key@app.getsentry.com/12345")

        // -- Assert --
        XCTAssertNil(dsn.orgId)
    }
}
