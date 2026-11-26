#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryExtensionDetectorTests: XCTestCase {
    private let extensionKey = "NSExtension"
    private let extensionKitKey = "EXAppExtensionAttributes"

    func testGetExtensionPointIdentifier_whenNoExtensionKeys_shouldReturnNil() {
        // -- Arrange --
        let infoPlistWrapper = TestInfoPlistWrapper()
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: extensionKey,
            error: SentryInfoPlistError.keyNotFound(key: extensionKey)
        )
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: extensionKitKey,
            error: SentryInfoPlistError.keyNotFound(key: extensionKitKey)
        )
        let sut = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)

        // -- Act --
        let result = sut.getExtensionPointIdentifier()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testGetExtensionPointIdentifier_whenMainInfoPlistNotFound_shouldReturnNil() {
        // -- Arrange --
        let infoPlistWrapper = TestInfoPlistWrapper()
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: extensionKey,
            error: SentryInfoPlistError.mainInfoPlistNotFound
        )
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: extensionKitKey,
            error: SentryInfoPlistError.mainInfoPlistNotFound
        )
        let sut = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)

        // -- Act --
        let result = sut.getExtensionPointIdentifier()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testGetExtensionPointIdentifier_whenNSExtension_shouldReturnNSExtensionPointIdentifier() {
        // -- Arrange --
        let infoPlistWrapper = TestInfoPlistWrapper()
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: extensionKey,
            value: ["NSExtensionPointIdentifier": "com.apple.share-services"]
        )
        let sut = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)

        // -- Act --
        let result = sut.getExtensionPointIdentifier()

        // -- Assert --
        XCTAssertEqual(result, "com.apple.share-services")
        XCTAssertEqual(infoPlistWrapper.getAppValueDictionaryInvocations.invocations, [extensionKey])
    }

    func testGetExtensionPointIdentifier_whenExtensionKitExtension_shouldReturnEXExtensionPointIdentifier() {
        // -- Arrange --
        let infoPlistWrapper = TestInfoPlistWrapper()
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: extensionKey,
            error: SentryInfoPlistError.keyNotFound(key: extensionKey)
        )
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: extensionKitKey,
            value: ["EXExtensionPointIdentifier": "com.apple.contact.provider.extension"]
        )
        let sut = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)

        // -- Act --
        let result = sut.getExtensionPointIdentifier()

        // -- Assert --
        XCTAssertEqual(result, "com.apple.contact.provider.extension")
    }

    func testGetExtensionPointIdentifier_whenNSExtensionWithoutPointIdentifier_shouldReturnEXExtensionPointIdentifier() {
        // -- Arrange --
        let infoPlistWrapper = TestInfoPlistWrapper()
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(forKey: extensionKey, value: [:])
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: extensionKitKey,
            value: ["EXExtensionPointIdentifier": "com.apple.contact.provider.extension"]
        )
        let sut = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)

        // -- Act --
        let result = sut.getExtensionPointIdentifier()

        // -- Assert --
        XCTAssertEqual(result, "com.apple.contact.provider.extension")
    }

    func testGetExtensionPointIdentifier_whenExtensionKitAttributesHaveWrongType_shouldReturnNil() {
        // -- Arrange --
        let infoPlistWrapper = TestInfoPlistWrapper()
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: extensionKey,
            error: SentryInfoPlistError.keyNotFound(key: extensionKey)
        )
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: extensionKitKey,
            error: SentryInfoPlistError.unableToCastValue(key: extensionKitKey, value: "invalid", type: [String: Any].self)
        )
        let sut = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)

        // -- Act --
        let result = sut.getExtensionPointIdentifier()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testGetExtensionPointIdentifier_whenExtensionKitPointIdentifierIsNotAString_shouldReturnNil() {
        // -- Arrange --
        let infoPlistWrapper = TestInfoPlistWrapper()
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: extensionKey,
            error: SentryInfoPlistError.keyNotFound(key: extensionKey)
        )
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: extensionKitKey,
            value: ["EXExtensionPointIdentifier": 1]
        )
        let sut = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)

        // -- Act --
        let result = sut.getExtensionPointIdentifier()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testIsDisabledExtensionPointIdentifier_whenContactProvider_shouldReturnTrue() {
        XCTAssertTrue("com.apple.contact.provider.extension".isDisabledExtensionPointIdentifier)
    }

    func testIsDisabledExtensionPointIdentifier_whenKeyboard_shouldReturnFalse() {
        XCTAssertFalse("com.apple.keyboard-service".isDisabledExtensionPointIdentifier)
    }
}
