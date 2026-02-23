import SentrySampleShared
import XCTest

final class FeedbackUITests: XCTestCase {
    func testWidgetDisplayInSwiftUIApp() throws {
        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: [
            SentrySDKOverrides.Feedback.allDefaults.rawValue,
            SentrySDKOverrides.Profiling.disableAppStartProfiling.rawValue
        ])
        app.launch()

        // ensure the widget button is displayed
        XCTAssert(app.otherElements["Report a Bug"].exists)

        // ensure tapping the widget displays the form
        app.otherElements["io.sentry.feedback.widget"].tap()
        XCTAssert(app.staticTexts["Report a Bug"].exists)

        // ensure cancelling the flow hides the form and redisplays the widget
        app.buttons["io.sentry.feedback.form.cancel"].tap()
        XCTAssert(app.otherElements["Report a Bug"].exists)
    }
}
