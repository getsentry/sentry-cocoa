@_spi(Private) @testable import Sentry
import XCTest

final class SentryExtensionTypeTests: XCTestCase {
    func testWidget_shouldReturnExpectedIdentifier() {
        XCTAssertEqual(SentryExtensionType.widget.identifier, "com.apple.widgetkit-extension")
    }

    func testIntent_shouldReturnExpectedIdentifier() {
        XCTAssertEqual(SentryExtensionType.intent.identifier, "com.apple.intents-service")
    }

    func testAction_shouldReturnExpectedIdentifier() {
        XCTAssertEqual(SentryExtensionType.action.identifier, "com.apple.ui-services")
    }

    func testShare_shouldReturnExpectedIdentifier() {
        XCTAssertEqual(SentryExtensionType.share.identifier, "com.apple.share-services")
    }
}
