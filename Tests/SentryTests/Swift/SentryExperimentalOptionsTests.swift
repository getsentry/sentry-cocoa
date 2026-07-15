@testable import Sentry
import XCTest

class SentryExperimentalOptionsTests: XCTestCase {

    func testMarkRecursivelyAsModified_shouldMarkDataCollectionAndUserInfoAsModified() {
        // -- Arrange --
        let sut = SentryExperimentalOptions()

        // -- Act --
        sut.markRecursivelyAsModified()

        // -- Assert --
        XCTAssertTrue(sut._dataCollection.isModified)
        XCTAssertTrue(sut.dataCollection._userInfo.isModified)
    }
}
