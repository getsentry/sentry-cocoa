@testable import Sentry
import XCTest

class SentryDatabaseCollectionOptionsTests: XCTestCase {

    func testInit_withoutArguments_shouldDefaultToTrue() {
        let options = SentryDataCollection.DatabaseCollectionOptions()
        XCTAssertTrue(options.queryParams)
    }

    func testInit_withArguments_shouldSetProperties() {
        let options = SentryDataCollection.DatabaseCollectionOptions(queryParams: false)
        XCTAssertFalse(options.queryParams)
    }
}
