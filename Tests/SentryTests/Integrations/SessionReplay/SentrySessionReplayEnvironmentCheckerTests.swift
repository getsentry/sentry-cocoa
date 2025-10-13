@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentrySessionReplayEnvironmentCheckerTests: XCTestCase {

    private var infoPlistWrapper: TestInfoPlistWrapper!
    private var sut: SentrySessionReplayEnvironmentChecker!

    override func setUp() {
        super.setUp()
        infoPlistWrapper = TestInfoPlistWrapper()
        
        // Set up default mocks to prevent precondition failures
        // Individual tests can override these as needed
        
        // Default: compatibility mode not set (key not found = unclear)
        infoPlistWrapper.mockGetAppValueBooleanThrowError(
            forKey: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
            error: SentryInfoPlistError.keyNotFound(key: SentryInfoPlistKey.designRequiresCompatibility.rawValue) as NSError
        )
        
        // Default: Xcode version not set (key not found = unclear)
        infoPlistWrapper.mockGetAppValueStringThrowError(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            error: SentryInfoPlistError.keyNotFound(key: SentryInfoPlistKey.xcodeVersion.rawValue)
        )
        
        sut = SentrySessionReplayEnvironmentChecker(infoPlistWrapper: infoPlistWrapper)
    }

    override func tearDown() {
        sut = nil
        infoPlistWrapper = nil
        super.tearDown()
    }

    // MARK: - iOS Version Check Tests

    func testIsReliable_onIOSOlderThan26_returnsTrue() throws {
        // iOS < 26.0 is always reliable (no Liquid Glass)
        guard #unavailable(iOS 26.0) else {
            throw XCTSkip("Test requires iOS < 26.0")
        }

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertTrue(result, "iOS < 26.0 should always be reliable")
    }

    // MARK: - Compatibility Mode Tests (iOS 26+)

    func testIsReliable_onIOS26_withCompatibilityModeYES_returnsTrue() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueBooleanReturnValue(
            forKey: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
            value: true
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertTrue(result, "UIDesignRequiresCompatibility = YES should make environment reliable")
    }

    func testIsReliable_onIOS26_withCompatibilityModeNO_withOldXcode_returnsTrue() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueBooleanReturnValue(
            forKey: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
            value: false
        )
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "\(SentryXcodeVersion.xcode16_4.rawValue)" // Xcode 16.4 < 26.0
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertTrue(result, "Xcode < 26.0 should make environment reliable even with compatibility mode NO")
    }

    func testIsReliable_onIOS26_withCompatibilityModeNO_withNewXcode_returnsFalse() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueBooleanReturnValue(
            forKey: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
            value: false
        )
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "\(SentryXcodeVersion.xcode26.rawValue)" // Xcode 26.0
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertFalse(result, "iOS 26+ with compatibility mode NO and Xcode >= 26.0 should be unreliable")
    }

    // MARK: - Xcode Version Tests (iOS 26+)

    func testIsReliable_onIOS26_withXcodeOlderThan26_returnsTrue() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "\(SentryXcodeVersion.xcode16_4.rawValue)" // Xcode 16.4
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertTrue(result, "Xcode < 26.0 should make environment reliable")
    }

    func testIsReliable_onIOS26_withXcode26OrNewer_returnsFalse() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "\(SentryXcodeVersion.xcode26.rawValue)" // Xcode 26.0
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertFalse(result, "Xcode >= 26.0 on iOS 26+ should be unreliable")
    }

    func testIsReliable_onIOS26_withInvalidXcodeVersion_returnsFalse() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "invalid_version"
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertFalse(result, "Invalid Xcode version should be treated as unreliable (defensive)")
    }

    func testIsReliable_onIOS26_withMissingXcodeVersion_returnsFalse() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueStringThrowError(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            error: SentryInfoPlistError.keyNotFound(key: SentryInfoPlistKey.xcodeVersion.rawValue)
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertFalse(result, "Missing Xcode version should be treated as unreliable (defensive)")
    }

    // MARK: - Compatibility Mode Error Handling Tests (iOS 26+)

    func testIsReliable_onIOS26_withMissingCompatibilityKey_withOldXcode_returnsTrue() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueBooleanThrowError(
            forKey: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
            error: SentryInfoPlistError.keyNotFound(key: SentryInfoPlistKey.designRequiresCompatibility.rawValue) as NSError
        )
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "1640" // Xcode 16.4
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertTrue(result, "Old Xcode version should make it reliable even without compatibility key")
    }

    func testIsReliable_onIOS26_withMissingCompatibilityKey_withNewXcode_returnsFalse() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueBooleanThrowError(
            forKey: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
            error: SentryInfoPlistError.keyNotFound(key: SentryInfoPlistKey.designRequiresCompatibility.rawValue) as NSError
        )
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "2600" // Xcode 26.0
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertFalse(result, "New Xcode with missing compatibility key should be unreliable")
    }

    func testIsReliable_onIOS26_withInfoPlistNotFound_returnsFalse() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueBooleanThrowError(
            forKey: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
            error: SentryInfoPlistError.mainInfoPlistNotFound as NSError
        )
        infoPlistWrapper.mockGetAppValueStringThrowError(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            error: SentryInfoPlistError.mainInfoPlistNotFound as Error
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertFalse(result, "Missing Info.plist should be treated as unreliable (defensive)")
    }

    // MARK: - Edge Cases and Error Handling (iOS 26+)

    func testIsReliable_onIOS26_withAllChecksUnclear_returnsFalse() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange - all checks return unclear
        infoPlistWrapper.mockGetAppValueBooleanThrowError(
            forKey: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
            error: SentryInfoPlistError.keyNotFound(key: SentryInfoPlistKey.designRequiresCompatibility.rawValue) as NSError
        )
        infoPlistWrapper.mockGetAppValueStringThrowError(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            error: SentryInfoPlistError.keyNotFound(key: SentryInfoPlistKey.xcodeVersion.rawValue)
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertFalse(result, "When all checks are unclear, should be treated as unreliable (defensive)")
    }

    func testIsReliable_onIOS26_withXcodeExactly2600_returnsFalse() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "2600" // Exactly Xcode 26.0
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertFalse(result, "Xcode 26.0 (exactly) should be unreliable")
    }

    func testIsReliable_onIOS26_withXcodeExactly2599_returnsTrue() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "2599" // Just before Xcode 26.0
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertTrue(result, "Xcode 25.9.9 (< 26.0) should be reliable")
    }

    // MARK: - Multiple Reliable Conditions Tests (iOS 26+)

    func testIsReliable_onIOS26_withMultipleReliableConditions_returnsTrue() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange - both compatibility mode AND old Xcode
        infoPlistWrapper.mockGetAppValueBooleanReturnValue(
            forKey: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
            value: true
        )
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "1640" // Xcode 16.4
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertTrue(result, "Multiple reliable conditions should make environment reliable")
    }

    // MARK: - Real-World Scenario Tests (iOS 26+)

    func testIsReliable_typicalNewApp_onIOS26_withXcode26_returnsFalse() throws {
        // Typical scenario: New app built with Xcode 26 running on iOS 26
        // Should be detected as unreliable (Liquid Glass will be used)
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "2600"
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertFalse(result, "Typical new app on iOS 26 with Xcode 26 should be unreliable")
    }

    func testIsReliable_legacyApp_onIOS26_withXcode16_returnsTrue() throws {
        // Legacy scenario: Old app built with Xcode 16 running on iOS 26
        // Should be detected as reliable (Liquid Glass won't be used)
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "1600"
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertTrue(result, "Legacy app built with Xcode 16 on iOS 26 should be reliable")
    }

    func testIsReliable_appOptingIntoCompatibility_onIOS26_withXcode26_returnsTrue() throws {
        // Scenario: New app with Xcode 26 but explicitly opts into compatibility mode
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("Test requires iOS 26.0+")
        }

        // Arrange
        infoPlistWrapper.mockGetAppValueBooleanReturnValue(
            forKey: SentryInfoPlistKey.designRequiresCompatibility.rawValue,
            value: true
        )
        infoPlistWrapper.mockGetAppValueStringReturnValue(
            forKey: SentryInfoPlistKey.xcodeVersion.rawValue,
            value: "2600"
        )

        // Act
        let result = sut.isReliable()

        // Assert
        XCTAssertTrue(result, "App with compatibility mode enabled should be reliable")
    }
}
