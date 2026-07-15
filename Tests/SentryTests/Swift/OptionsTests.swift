@testable import Sentry
import XCTest

class OptionsTests: XCTestCase {

    func testSendDefaultPii_whenSet_shouldMarkAsModified() {
        // -- Arrange --
        let sut = Options()

        // -- Act --
        sut.sendDefaultPii = true

        // -- Assert --
        XCTAssertTrue(sut._sendDefaultPii.isModified)
    }

    func testExperimental_whenSet_shouldMarkExperimentalDataCollectionAndUserInfoAsModified() {
        // -- Arrange --
        let sut = Options()

        // -- Act --
        sut.experimental = SentryExperimentalOptions()

        // -- Assert --
        XCTAssertTrue(sut._experimental.isModified)
        XCTAssertTrue(sut.experimental._dataCollection.isModified)
        XCTAssertTrue(sut.experimental.dataCollection._userInfo.isModified)
    }
}
