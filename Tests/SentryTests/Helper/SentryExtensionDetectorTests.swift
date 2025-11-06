@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryExtensionDetectorTests: XCTestCase {
    
    private var infoPlistWrapper: TestInfoPlistWrapper!
    private var sut: SentryExtensionDetector!
    
    override func setUp() {
        super.setUp()
        infoPlistWrapper = TestInfoPlistWrapper()
        
        // Default: NSExtension key not found (not an extension)
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: SentryInfoPlistKey.extension.rawValue,
            error: SentryInfoPlistError.keyNotFound(key: SentryInfoPlistKey.extension.rawValue)
        )
        
        sut = SentryExtensionDetector(infoPlistWrapper: infoPlistWrapper)
    }
    
    override func tearDown() {
        sut = nil
        infoPlistWrapper = nil
        super.tearDown()
    }
    
    // MARK: - Extension Point Identifier Detection
    
    func testGetExtensionPointIdentifier_notAnExtension() {
        // Arrange & Act
        let extensionPointIdentifier = sut.getExtensionPointIdentifier()
        
        // Assert
        XCTAssertNil(extensionPointIdentifier, "Non-extension should return nil")
    }
    
    func testGetExtensionPointIdentifier_widgetExtension() {
        // Arrange
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.widgetkit-extension"]
        )
        
        // Act
        let identifier = sut.getExtensionPointIdentifier()
        
        // Assert
        XCTAssertEqual(identifier, "com.apple.widgetkit-extension")
    }
    
    func testGetExtensionPointIdentifier_intentExtension() {
        // Arrange
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.intents-service"]
        )
        
        // Act
        let identifier = sut.getExtensionPointIdentifier()
        
        // Assert
        XCTAssertEqual(identifier, "com.apple.intents-service")
    }
    
    func testGetExtensionPointIdentifier_actionExtension() {
        // Arrange
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.ui-services"]
        )
        
        // Act
        let identifier = sut.getExtensionPointIdentifier()
        
        // Assert
        XCTAssertEqual(identifier, "com.apple.ui-services")
    }
    
    // MARK: - App Hang Tracking Disable Detection
    
    func testShouldDisableAppHangTracking_notAnExtension() {
        // Arrange & Act
        let shouldDisable = sut.shouldDisableAppHangTracking()
        
        // Assert
        XCTAssertFalse(shouldDisable, "Non-extension should not disable app hang tracking")
    }
    
    func testShouldDisableAppHangTracking_widgetExtension() {
        // Arrange
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.widgetkit-extension"]
        )
        
        // Act
        let shouldDisable = sut.shouldDisableAppHangTracking()
        
        // Assert
        XCTAssertTrue(shouldDisable, "Widget extension should disable app hang tracking")
    }
    
    func testShouldDisableAppHangTracking_intentExtension() {
        // Arrange
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.intents-service"]
        )
        
        // Act
        let shouldDisable = sut.shouldDisableAppHangTracking()
        
        // Assert
        XCTAssertTrue(shouldDisable, "Intent extension should disable app hang tracking")
    }
    
    func testShouldDisableAppHangTracking_actionExtension() {
        // Arrange
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.ui-services"]
        )
        
        // Act
        let shouldDisable = sut.shouldDisableAppHangTracking()
        
        // Assert
        XCTAssertTrue(shouldDisable, "Action extension should disable app hang tracking")
    }
    
    func testShouldDisableAppHangTracking_unknownExtension() {
        // Arrange - extension with unknown identifier
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": "com.apple.unknown-extension"]
        )
        
        // Act
        let shouldDisable = sut.shouldDisableAppHangTracking()
        
        // Assert
        XCTAssertFalse(shouldDisable, "Unknown extension type should not disable app hang tracking")
    }
    
    // MARK: - Error Handling Tests
    
    func testGetExtensionPointIdentifier_withInfoPlistNotFound_returnsNil() {
        // Arrange
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: SentryInfoPlistKey.extension.rawValue,
            error: SentryInfoPlistError.mainInfoPlistNotFound
        )
        
        // Act
        let identifier = sut.getExtensionPointIdentifier()
        
        // Assert
        XCTAssertNil(identifier, "Missing Info.plist should return nil")
    }
    
    func testGetExtensionPointIdentifier_withKeyNotFound_returnsNil() {
        // Arrange
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: SentryInfoPlistKey.extension.rawValue,
            error: SentryInfoPlistError.keyNotFound(key: SentryInfoPlistKey.extension.rawValue)
        )
        
        // Act
        let identifier = sut.getExtensionPointIdentifier()
        
        // Assert
        XCTAssertNil(identifier, "Missing NSExtension key should return nil")
    }
    
    func testGetExtensionPointIdentifier_withUnableToCast_returnsNil() {
        // Arrange
        infoPlistWrapper.mockGetAppValueDictionaryThrowError(
            forKey: SentryInfoPlistKey.extension.rawValue,
            error: SentryInfoPlistError.unableToCastValue(
                key: SentryInfoPlistKey.extension.rawValue,
                value: "not a dictionary",
                type: [String: Any].self
            )
        )
        
        // Act
        let identifier = sut.getExtensionPointIdentifier()
        
        // Assert
        XCTAssertNil(identifier, "Cast error should return nil")
    }
    
    func testGetExtensionPointIdentifier_withMissingPointIdentifier_returnsNil() {
        // Arrange - NSExtension exists but NSExtensionPointIdentifier is missing
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: [:] // Empty dictionary
        )
        
        // Act
        let identifier = sut.getExtensionPointIdentifier()
        
        // Assert
        XCTAssertNil(identifier, "Missing NSExtensionPointIdentifier in dictionary should return nil")
    }
    
    func testGetExtensionPointIdentifier_withWrongTypePointIdentifier_returnsNil() {
        // Arrange - NSExtensionPointIdentifier exists but is wrong type
        infoPlistWrapper.mockGetAppValueDictionaryReturnValue(
            forKey: SentryInfoPlistKey.extension.rawValue,
            value: ["NSExtensionPointIdentifier": 123] // Integer instead of String
        )
        
        // Act
        let identifier = sut.getExtensionPointIdentifier()
        
        // Assert
        XCTAssertNil(identifier, "Wrong type for NSExtensionPointIdentifier should return nil")
    }
}
