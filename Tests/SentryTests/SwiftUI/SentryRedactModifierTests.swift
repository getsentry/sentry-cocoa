#if canImport(UIKit) && canImport(SwiftUI)
@testable import Sentry
@testable import SentrySwiftUI
import SwiftUI
import XCTest

class SentryRedactModifierTests: XCTestCase {

    func testViewRedacted() throws {
        let text = Text("Hello, World!")
        let redactedText = text.sentryReplayMask()
        
        XCTAssertTrue(redactedText is ModifiedContent<Text, SentryReplayModifier>)
    }

}

#endif
