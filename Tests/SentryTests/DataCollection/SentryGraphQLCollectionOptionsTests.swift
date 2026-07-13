@testable import Sentry
import XCTest

class SentryGraphQLCollectionOptionsTests: XCTestCase {

    func testInit_withoutArguments_shouldDefaultToTrue() {
        let options = SentryDataCollection.GraphQLCollectionOptions()
        XCTAssertTrue(options.document)
        XCTAssertTrue(options.variables)
    }

    func testInit_withArguments_shouldSetProperties() {
        let options = SentryDataCollection.GraphQLCollectionOptions(document: false, variables: true)
        XCTAssertFalse(options.document)
        XCTAssertTrue(options.variables)
    }
}
