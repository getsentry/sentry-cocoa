#if canImport(UIKit) && canImport(SwiftUI)
@testable import Sentry
@testable import SentrySwiftUI
import SwiftUI
import XCTest

class SentryRedactModifierTests: XCTestCase {
    func testViewMask() throws {
        let redactedText = Text("Hello, World!").sentryReplayMask()
        let description = String(describing: redactedText)
        XCTAssertTrue(description.starts(with: "AnyView(ModifiedContent<Text, SentryReplayModifier>"), "Redacted text is \(description)")
    }
    
    func testViewUnmask() throws {
        let unmaskedText = Text("Hello, World!").sentryReplayUnmask()
        let description = String(describing: unmaskedText)
        XCTAssertTrue(description.starts(with: "AnyView(ModifiedContent<Text, SentryReplayModifier>"), "Unmasked text is \(description)")
    }
}

#endif
