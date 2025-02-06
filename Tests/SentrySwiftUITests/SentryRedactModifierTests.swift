#if canImport(UIKit) && canImport(SwiftUI)
@testable import Sentry
@testable import SentrySwiftUI
import SwiftUI
import XCTest

class SentryRedactModifierTests: XCTestCase {
    func testViewMask() throws {
        // -- Arrange --
        let text = Text("Hello, World!")
        // -- Act --
        let redactedText = text.sentryReplayMask()
        // -- Assert --
        // We can not use the `type(of:)` or `is` to compare the response, because the type is erased to `AnyView`.
        let typeOfRedactedText = String(describing: redactedText)

        // As the actual type is part of SwiftUI and somewhat unpredictable, we need to have multiple assertions.
        // Eventually this can be replaced with a more stable solution.
        let expected: String
        if #available(iOS 18.0, *) {
            expected = "ModifiedContent<Text, SentryReplayModifier>"
        } else {
            expected = "SwiftUI.ModifiedContent<SwiftUI.Text, SentrySwiftUI.SentryReplayModifier>"
        }
        XCTAssertTrue(
            typeOfRedactedText.contains(expected),
            "Expected type to contain '\(expected)' but was: \(typeOfRedactedText)"
        )
    }
    
    func testViewUnmask() throws {
        // -- Arrange --
        let text = Text("Hello, World!")
        // -- Act --
        let redactedText = text.sentryReplayUnmask()
        // -- Assert --
        // We can not use the `type(of:)` or `is` to compare the response, because the type is erased to `AnyView`.
        let typeOfRedactedText = String(describing: redactedText)
        // As the actual type is part of SwiftUI and somewhat unpredictable, we need to have multiple assertions.
        // Eventually this can be replaced with a more stable solution.
        let expected: String
        if #available(iOS 18.0, *) {
            expected = "ModifiedContent<Text, SentryReplayModifier>"
        } else {
            expected = "SwiftUI.ModifiedContent<SwiftUI.Text, SentrySwiftUI.SentryReplayModifier>"
        }
        XCTAssertTrue(
            typeOfRedactedText.contains(expected),
            "Expected type to contain '\(expected)' but was: \(typeOfRedactedText)"
        )
    }
}

#endif
