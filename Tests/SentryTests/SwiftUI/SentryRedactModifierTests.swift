#if canImport(UIKit) && canImport(SwiftUI)
@testable import Sentry
@testable import SentrySwiftUI
import SwiftUI
import XCTest

class SentryRedactModifierTests: XCTestCase {

    func testViewMask() throws {
        let text = Text("Hello, World!")
        let redactedText = text.sentryReplayMask()
        
        XCTAssertTrue(redactedText is ModifiedContent<Text, SentryReplayModifier>)
    }
    
    func testViewUnmask() throws {
        let text = Text("Hello, World!")
        let redactedText = text.sentryReplayUnmask()
        
        XCTAssertTrue(redactedText is ModifiedContent<Text, SentryReplayModifier>)
    }

}

#endif
