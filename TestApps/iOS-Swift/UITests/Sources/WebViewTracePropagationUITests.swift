import XCTest

class WebViewTracePropagationUITests: BaseUITest {

    func testWebView_shouldInjectTraceBeforePageScripts() {
        // -- Act --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["Web View"].tap()

        // -- Assert --
        assertPageShowsInjectedTrace()
    }

    func testWebPage_shouldInjectTraceBeforePageScripts() throws {
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("SwiftUI WebPage requires iOS 26.")
        }
        // -- Arrange --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["Web View"].tap()

        // -- Act --
        app.buttons["webview-swiftui"].tap()

        // -- Assert --
        XCTAssertTrue(app.navigationBars["WebPage"].waitForExistence(timeout: 10), "The WebPage screen didn't open.")
        assertPageShowsInjectedTrace()
    }

    /// The page's first script reads the tag and shows it, so this works without network access.
    private func assertPageShowsInjectedTrace(file: StaticString = #filePath, line: UInt = #line) {
        let trace = app.webViews.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'sentry-trace: '")).firstMatch
        XCTAssertTrue(trace.waitForExistence(timeout: 30), "The page didn't show the injected trace.", file: file, line: line)
        let value = String(trace.label.dropFirst("sentry-trace: ".count))
        XCTAssertNotNil(
            value.range(of: "^[0-9a-f]{32}-[0-9a-f]{16}(-[01])?$", options: .regularExpression),
            "Unexpected sentry-trace value: \(value)",
            file: file,
            line: line
        )
    }
}
