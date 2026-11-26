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

    func testExistingWebView_shouldInjectTraceOnNextNavigation() {
        // -- Arrange --
        app.tabBars.buttons["Extra"].tap()
        app.buttons["Web View"].tap()

        // -- Act --
        app.buttons["webview-existing"].tap()

        // -- Assert --
        XCTAssertTrue(app.navigationBars["Existing"].waitForExistence(timeout: 10), "The existing web view screen didn't open.")
        assertPageShowsInjectedTrace()
    }

    /// The page's first script reads the tag and shows it, so this works without network access.
    /// The page also shows the app's trace, so this checks that the injected tag continues it.
    private func assertPageShowsInjectedTrace(file: StaticString = #filePath, line: UInt = #line) {
        let value = pageValue(prefix: "sentry-trace: ", file: file, line: line)
        XCTAssertNotNil(
            value.range(of: "^[0-9a-f]{32}-[0-9a-f]{16}(-[01])?$", options: .regularExpression),
            "Unexpected sentry-trace value: \(value)",
            file: file,
            line: line
        )
        let nativeTraceId = pageValue(prefix: "native-trace: ", file: file, line: line)
        XCTAssertEqual(value.components(separatedBy: "-").first, nativeTraceId, "The page didn't get the app's trace.", file: file, line: line)
    }

    private func pageValue(prefix: String, file: StaticString, line: UInt) -> String {
        let text = app.webViews.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 30), "The page didn't show \(prefix)", file: file, line: line)
        return String(text.label.dropFirst(prefix.count))
    }
}
