@testable import Sentry
import XCTest

class SentryDefaultEventContextEnricherTests: XCTestCase {

    // MARK: - UIKit Platform Tests

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT

    // MARK: - Active State Tests

    func testEnrichEventContext_WhenActive_SetsIsActiveTrueAndInForegroundTrue() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .active })

        // Act
        let result = sut.enrichWithAppState([:])

        // Assert
        let appContext = try XCTUnwrap(result["app"] as? [String: Any])
        XCTAssertTrue(try XCTUnwrap(appContext["is_active"] as? Bool))
        XCTAssertTrue(try XCTUnwrap(appContext["in_foreground"] as? Bool))
    }

    // MARK: - Inactive State Tests

    func testEnrichEventContext_WhenInactive_SetsIsActiveFalseAndInForegroundTrue() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .inactive })

        // Act
        let result = sut.enrichWithAppState([:])

        // Assert
        let appContext = try XCTUnwrap(result["app"] as? [String: Any])
        XCTAssertFalse(try XCTUnwrap(appContext["is_active"] as? Bool))
        XCTAssertTrue(try XCTUnwrap(appContext["in_foreground"] as? Bool))
    }

    // MARK: - Background State Tests

    func testEnrichEventContext_WhenBackground_SetsIsActiveFalseAndInForegroundFalse() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .background })

        // Act
        let result = sut.enrichWithAppState([:])

        // Assert
        let appContext = try XCTUnwrap(result["app"] as? [String: Any])
        XCTAssertFalse(try XCTUnwrap(appContext["is_active"] as? Bool))
        XCTAssertFalse(try XCTUnwrap(appContext["in_foreground"] as? Bool))
    }

    // MARK: - Existing Context Tests

    func testEnrichEventContext_WhenContextHasOtherData_PreservesIt() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .active })
        let context: [String: Any] = [
            "device": ["model": "iPhone"],
            "user": ["id": "123"]
        ]

        // Act
        let result = sut.enrichWithAppState(context)

        // Assert
        let deviceContext = try XCTUnwrap(result["device"] as? [String: String])
        XCTAssertEqual(deviceContext["model"], "iPhone")
        let userContext = try XCTUnwrap(result["user"] as? [String: String])
        XCTAssertEqual(userContext["id"], "123")
    }

    func testEnrichEventContext_WhenAppContextExists_PreservesOtherAppData() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .active })
        let context: [String: Any] = [
            "app": [
                "app_version": "1.0.0",
                "app_build": "100"
            ]
        ]

        // Act
        let result = sut.enrichWithAppState(context)

        // Assert
        let appContext = try XCTUnwrap(result["app"] as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(appContext["app_version"] as? String), "1.0.0")
        XCTAssertEqual(try XCTUnwrap(appContext["app_build"] as? String), "100")
        XCTAssertTrue(try XCTUnwrap(appContext["is_active"] as? Bool))
        XCTAssertTrue(try XCTUnwrap(appContext["in_foreground"] as? Bool))
    }

    // MARK: - Do Not Overwrite Existing Values Tests

    func testEnrichEventContext_WhenInForegroundAlreadySet_DoesNotOverwrite() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .active })
        let context: [String: Any] = [
            "app": ["in_foreground": false]
        ]

        // Act
        let result = sut.enrichWithAppState(context)

        // Assert
        let appContext = try XCTUnwrap(result["app"] as? [String: Any])
        XCTAssertFalse(try XCTUnwrap(appContext["in_foreground"] as? Bool))
        XCTAssertTrue(try XCTUnwrap(appContext["is_active"] as? Bool))
    }

    func testEnrichEventContext_WhenIsActiveAlreadySet_DoesNotOverwrite() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .background })
        let context: [String: Any] = [
            "app": ["is_active": true]
        ]

        // Act
        let result = sut.enrichWithAppState(context)

        // Assert
        let appContext = try XCTUnwrap(result["app"] as? [String: Any])
        XCTAssertTrue(try XCTUnwrap(appContext["is_active"] as? Bool))
        XCTAssertFalse(try XCTUnwrap(appContext["in_foreground"] as? Bool))
    }

    func testEnrichEventContext_WhenBothFieldsAlreadySet_DoesNotModify() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .active })
        let context: [String: Any] = [
            "app": [
                "in_foreground": false,
                "is_active": false,
                "app_version": "1.0.0"
            ]
        ]

        // Act
        let result = sut.enrichWithAppState(context)

        // Assert
        let appContext = try XCTUnwrap(result["app"] as? [String: Any])
        XCTAssertFalse(try XCTUnwrap(appContext["in_foreground"] as? Bool))
        XCTAssertFalse(try XCTUnwrap(appContext["is_active"] as? Bool))
        XCTAssertEqual(try XCTUnwrap(appContext["app_version"] as? String), "1.0.0")
    }

    // MARK: - Nil/Empty Context Tests

    func testEnrichEventContext_WhenContextIsEmpty_CreatesAppContext() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .active })

        // Act
        let result = sut.enrichWithAppState([:])

        // Assert
        let appContext = try XCTUnwrap(result["app"] as? [String: Any])
        XCTAssertTrue(try XCTUnwrap(appContext["is_active"] as? Bool))
        XCTAssertTrue(try XCTUnwrap(appContext["in_foreground"] as? Bool))
    }

    // MARK: - Custom Value Preservation Tests

    func testEnrichEventContext_WhenInForegroundIsString_DoesNotOverwrite() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .active })
        let context: [String: Any] = [
            "app": ["in_foreground": "custom-value"]
        ]

        // Act
        let result = sut.enrichWithAppState(context)

        // Assert
        let appContext = try XCTUnwrap(result["app"] as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(appContext["in_foreground"] as? String), "custom-value")
        XCTAssertTrue(try XCTUnwrap(appContext["is_active"] as? Bool))
    }

    // MARK: - Edge Cases

    func testEnrichEventContext_WhenApplicationStateIsNil_ReturnsUnchangedContext() {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { nil })
        let context: [String: Any] = [
            "device": ["model": "iPhone"]
        ]

        // Act
        let result = sut.enrichWithAppState(context)

        // Assert
        XCTAssertEqual(result as NSDictionary, context as NSDictionary)
        // Should not have added app context fields
        XCTAssertNil(result["app"])
    }

    func testEnrichEventContext_WhenAppContextIsInvalidType_ReturnsUnchangedAndLogsWarning() {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .active })
        let context: [String: Any] = [
            "app": "invalid-type",
            "device": ["model": "iPhone"]
        ]

        // Act
        let result = sut.enrichWithAppState(context)

        // Assert
        XCTAssertEqual(result as NSDictionary, context as NSDictionary)
        // Verify app field is still the invalid type (unchanged)
        XCTAssertEqual(result["app"] as? String, "invalid-type")
    }

    #endif

    // MARK: - Non-UIKit Platform Tests

    #if !(os(iOS) || os(tvOS) || os(visionOS)) || SENTRY_NO_UIKIT

    func testEnrichEventContext_OnNonUIKitPlatforms_ReturnsContextUnchanged() throws {
        // Arrange
        let sut = SentryDefaultEventContextEnricher()
        let originalContext: [String: Any] = [
            "device": ["model": "Mac"],
            "app": ["version": "1.0"]
        ]

        // Act
        let result = sut.enrichWithAppState(originalContext)

        // Assert
        // Context should be returned unchanged
        let deviceContext = try XCTUnwrap(result["device"] as? [String: String])
        XCTAssertEqual(deviceContext["model"], "Mac")
        let appContext = try XCTUnwrap(result["app"] as? [String: String])
        XCTAssertEqual(appContext["version"], "1.0")

        // No app state fields should be added
        let appContextAny = result["app"] as? [String: Any]
        XCTAssertNil(appContextAny?["in_foreground"])
        XCTAssertNil(appContextAny?["is_active"])
    }

    func testEnrichEventContext_OnNonUIKitPlatforms_WithEmptyContext_ReturnsEmpty() {
        // Arrange
        let sut = SentryDefaultEventContextEnricher()

        // Act
        let result = sut.enrichWithAppState([:])

        // Assert
        XCTAssertTrue(result.isEmpty)
    }

    #endif
}
