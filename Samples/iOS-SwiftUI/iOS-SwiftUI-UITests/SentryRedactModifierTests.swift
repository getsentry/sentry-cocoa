#if canImport(UIKit) && canImport(SwiftUI)
@testable import Sentry
@testable import SentrySwiftUI
import SwiftUI
import XCTest

class SentryRedactModifierTests: XCTestCase {

    func testViewMask() throws {
        let redactedText = Text("Hello, World!").sentryReplayMask()
        let description = String(describing: redactedText)
        XCTAssertTrue(description.starts(with: "AnyView(ModifiedContent<Text, SentryReplayModifier>"))
    }
    
    func testViewUnmask() throws {
        let redactedText = Text("Hello, World!").sentryReplayUnmask()
        let description = String(describing: redactedText)
        XCTAssertTrue(description.starts(with: "AnyView(ModifiedContent<Text, SentryReplayModifier>"))
    }

}

#endif
