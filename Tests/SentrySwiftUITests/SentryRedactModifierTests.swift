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
        XCTAssertTrue(typeOfRedactedText.hasPrefix("AnyView(ModifiedContent<Text, SentryReplayModifier>"))
    }
    
    func testViewUnmask() throws {
        // -- Arrange --
        let text = Text("Hello, World!")
        // -- Act --
        let redactedText = text.sentryReplayUnmask()
        // -- Assert --
        // We can not use the `type(of:)` or `is` to compare the response, because the type is erased to `AnyView`.
        let typeOfRedactedText = String(describing: redactedText)
        XCTAssertTrue(typeOfRedactedText.hasPrefix("AnyView(ModifiedContent<Text, SentryReplayModifier>"))
    }
}

#endif
