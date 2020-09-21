import XCTest

/**
 * Most of the tests are in SentryFileManagerTests.
 */
class SentryMigrateSessionInitTests: XCTestCase {

    func testWithGarbageParametersDoesNotCrash() {
        SentryMigrateSessionInit.migrateSessionInit("asdf", envelopesDirPath: "asdf", envelopeFilePaths: [])
    }
}
