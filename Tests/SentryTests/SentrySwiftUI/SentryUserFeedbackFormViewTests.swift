#if canImport(UIKit) && canImport(SwiftUI) && !SENTRY_NO_UI_FRAMEWORK && os(iOS)
@testable import Sentry
import SwiftUI
import XCTest

final class SentryUserFeedbackFormViewTests: XCTestCase {
    func testSentryFeedback_whenCalled_shouldReturnFeedbackModifier() {
        // -- Arrange --
        let text = Text("Hello, World!")

        // -- Act --
        let modifiedText = text.sentryFeedback(isPresented: .constant(false))

        // -- Assert --
        assertIsFeedbackModifier(modifiedText)
    }

    func testSentryFeedback_whenImagePassed_shouldReturnFeedbackModifier() {
        // -- Arrange --
        let text = Text("Hello, World!")

        // -- Act --
        let modifiedText = text.sentryFeedback(isPresented: .constant(false), image: nil)

        // -- Assert --
        assertIsFeedbackModifier(modifiedText)
    }

    private func assertIsFeedbackModifier(_ view: some View) {
        let typeDescription = String(describing: view)
        let candidates = [
            "ModifiedContent<Text, SentryUserFeedbackFormModifier>",
            "SwiftUI.ModifiedContent<SwiftUI.Text, Sentry.SentryUserFeedbackFormModifier>"
        ]
        XCTAssertTrue(
            candidates.contains(where: { typeDescription.contains($0) }),
            "Type did not match candidates: \(typeDescription)"
        )
    }
}
#endif
