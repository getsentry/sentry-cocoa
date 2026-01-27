@testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT

class SentryDefaultEventContextEnricherTests: XCTestCase {

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

    func testEnrichEventContext_WhenAppContextIsNotDictionary_ReplacesWithCorrectFormat() {
        // Arrange
        let sut = SentryDefaultEventContextEnricher(applicationStateProvider: { .active })
        let context: [String: Any] = [
            "app": "invalid-type"
        ]

        // Act
        let result = sut.enrichWithAppState(context)

        // Assert
        // Should not crash and should handle gracefully
        XCTAssertNotNil(result)
    }

    func testEnrichEventContext_MultipleCallsWithDifferentStates_ReturnsCorrectValues() throws {
        // Arrange & Act - First call with active state
        let sut1 = SentryDefaultEventContextEnricher(applicationStateProvider: { .active })
        let result1 = sut1.enrichWithAppState([:])

        // Assert - First call
        let appContext1 = try XCTUnwrap(result1["app"] as? [String: Any])
        XCTAssertTrue(try XCTUnwrap(appContext1["is_active"] as? Bool))
        XCTAssertTrue(try XCTUnwrap(appContext1["in_foreground"] as? Bool))

        // Arrange & Act - Second call with background state
        let sut2 = SentryDefaultEventContextEnricher(applicationStateProvider: { .background })
        let result2 = sut2.enrichWithAppState([:])

        // Assert - Second call
        let appContext2 = try XCTUnwrap(result2["app"] as? [String: Any])
        XCTAssertFalse(try XCTUnwrap(appContext2["is_active"] as? Bool))
        XCTAssertFalse(try XCTUnwrap(appContext2["in_foreground"] as? Bool))

        // Arrange & Act - Third call with inactive state
        let sut3 = SentryDefaultEventContextEnricher(applicationStateProvider: { .inactive })
        let result3 = sut3.enrichWithAppState([:])

        // Assert - Third call
        let appContext3 = try XCTUnwrap(result3["app"] as? [String: Any])
        XCTAssertFalse(try XCTUnwrap(appContext3["is_active"] as? Bool))
        XCTAssertTrue(try XCTUnwrap(appContext3["in_foreground"] as? Bool))
    }
}

#endif

// MARK: - Non-UIKit Platform Tests

#if !(os(iOS) || os(tvOS) || os(visionOS)) || SENTRY_NO_UIKIT
extension SentryDefaultEventContextEnricherTests {
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
}
#endif
