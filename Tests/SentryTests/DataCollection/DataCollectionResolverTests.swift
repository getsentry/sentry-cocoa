@_spi(Private) @testable import Sentry
import XCTest

final class DataCollectionResolverTests: XCTestCase {

    func testResolveAutoInferIP_whenNoOptionIsModified_shouldReturnFalse() {
        let result = DataCollectionResolver.resolveAutoInferIP(
            sendDefaultPii: SentryModifiable(false),
            userInfo: SentryModifiable(true)
        )

        XCTAssertFalse(result)
    }

    func testResolveAutoInferIP_whenSendDefaultPiiIsExplicitlyEnabled_shouldReturnTrue() {
        let result = DataCollectionResolver.resolveAutoInferIP(
            sendDefaultPii: SentryModifiable(true, isModified: true),
            userInfo: SentryModifiable(true)
        )

        XCTAssertTrue(result)
    }

    func testResolveAutoInferIP_whenSendDefaultPiiIsExplicitlyDisabled_shouldReturnFalse() {
        let result = DataCollectionResolver.resolveAutoInferIP(
            sendDefaultPii: SentryModifiable(false, isModified: true),
            userInfo: SentryModifiable(true)
        )

        XCTAssertFalse(result)
    }

    func testResolveAutoInferIP_whenUserInfoIsExplicitlyEnabled_shouldReturnTrue() {
        let result = DataCollectionResolver.resolveAutoInferIP(
            sendDefaultPii: SentryModifiable(false),
            userInfo: SentryModifiable(true, isModified: true)
        )

        XCTAssertTrue(result)
    }

    func testResolveAutoInferIP_whenUserInfoIsExplicitlyDisabled_shouldReturnFalse() {
        let result = DataCollectionResolver.resolveAutoInferIP(
            sendDefaultPii: SentryModifiable(true, isModified: true),
            userInfo: SentryModifiable(false, isModified: true)
        )

        XCTAssertFalse(result)
    }
}
