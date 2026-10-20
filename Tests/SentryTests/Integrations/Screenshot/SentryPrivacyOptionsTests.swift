#if SDK_V10 && (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation
import XCTest

class SentryPrivacyOptionsTests: XCTestCase {
    func testInit_withoutArguments_shouldMaskTextAndImages() {
        // -- Act --
        let options = Options()

        // -- Assert --
        XCTAssertTrue(options.privacy.maskAllText)
        XCTAssertTrue(options.privacy.maskAllImages)
        XCTAssertTrue(options.privacy.maskedViewClasses.isEmpty)
        XCTAssertTrue(options.privacy.unmaskedViewClasses.isEmpty)
        XCTAssertTrue(options.privacy.excludedViewClasses.isEmpty)
        XCTAssertTrue(options.privacy.includedViewClasses.isEmpty)
    }

    func testInit_withDictionary_shouldConfigurePrivacy() throws {
        // -- Arrange --
        let dictionary: [String: Any] = ["dsn": "https://username:password@sentry.io/1", "privacy": [
            "maskAllText": false,
            "maskAllImages": false,
            "maskedViewClasses": ["NSString", "UnknownClass"],
            "unmaskedViewClasses": ["NSNumber"],
            "excludedViewClasses": ["Excluded"],
            "includedViewClasses": ["Included"]
        ]]

        // -- Act --
        let options = try Options(dictionary: dictionary)

        // -- Assert --
        XCTAssertFalse(options.privacy.maskAllText)
        XCTAssertFalse(options.privacy.maskAllImages)
        XCTAssertEqual(options.privacy.maskedViewClasses.map(ObjectIdentifier.init), [ObjectIdentifier(NSString.self)])
        XCTAssertEqual(options.privacy.unmaskedViewClasses.map(ObjectIdentifier.init), [ObjectIdentifier(NSNumber.self)])
        XCTAssertEqual(options.privacy.excludedViewClasses, ["Excluded"])
        XCTAssertEqual(options.privacy.includedViewClasses, ["Included"])
    }

    func testInit_withEmptyDictionary_shouldPreserveSafeDefaults() throws {
        // -- Act --
        let options = try Options(dictionary: ["dsn": "https://username:password@sentry.io/1", "privacy": [:]])

        // -- Assert --
        XCTAssertTrue(options.privacy.maskAllText)
        XCTAssertTrue(options.privacy.maskAllImages)
    }

    func testTraversal_whenAddingTypes_shouldPreserveExistingTypes() {
        // -- Arrange --
        let options = SentryPrivacyOptions(excludedViewClasses: ["Existing"], includedViewClasses: ["Included"])

        // -- Act --
        options.excludeViewTypeFromSubtreeTraversal("Excluded")
        options.includeViewTypeInSubtreeTraversal("Restored")

        // -- Assert --
        XCTAssertEqual(options.excludedViewClasses, ["Existing", "Excluded"])
        XCTAssertEqual(options.includedViewClasses, ["Included", "Restored"])
    }
}
#endif
