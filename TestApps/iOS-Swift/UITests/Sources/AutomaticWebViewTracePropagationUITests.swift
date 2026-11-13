import SentrySampleShared
import XCTest

final class AutomaticWebViewTracePropagationUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testAutomaticWebView_whenEnabled_shouldInjectTraceOnLoadAndInPageNavigation() {
        // -- Arrange --
        launchApp(args: [SentrySDKOverrides.WebView.enableAutomaticTracing.rawValue])
        openAutomaticWebView()
        assertPageShowsInjectedTrace()

        // -- Act --
        // Following a link doesn't go through a `WKWebView` load method, so only the refreshed
        // script can inject the trace into the next page.
        let link = app.webViews.links["Next page"]
        XCTAssertTrue(link.waitForExistence(timeout: 30), "The page didn't show the link.")
        link.tap()

        // -- Assert --
        let nextPage = app.webViews.staticTexts["page: /next"]
        XCTAssertTrue(nextPage.waitForExistence(timeout: 30), "The next page didn't load.")
        assertPageShowsInjectedTrace()
    }

    func testAutomaticWebView_whenNotEnabled_shouldNotInjectTrace() {
        // -- Arrange --
        launchApp()

        // -- Act --
        openAutomaticWebView()

        // -- Assert --
        let trace = app.webViews.staticTexts["sentry-trace: not injected"]
        XCTAssertTrue(trace.waitForExistence(timeout: 30), "The page shouldn't receive a trace without options.webViewTracing.")
    }

    private func openAutomaticWebView() {
        app.tabBars.buttons["Extra"].tap()
        app.buttons["Web View"].tap()
        app.buttons["webview-automatic"].tap()
        XCTAssertTrue(app.navigationBars["Automatic"].waitForExistence(timeout: 10), "The automatic WebView screen didn't open.")
    }

    /// The page's first script reads the tag and shows it, so this works without network access.
    private func assertPageShowsInjectedTrace(file: StaticString = #filePath, line: UInt = #line) {
        let trace = app.webViews.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'sentry-trace: '")).firstMatch
        XCTAssertTrue(trace.waitForExistence(timeout: 30), "The page didn't show the trace.", file: file, line: line)
        let value = String(trace.label.dropFirst("sentry-trace: ".count))
        XCTAssertNotNil(
            value.range(of: "^[0-9a-f]{32}-[0-9a-f]{16}(-[01])?$", options: .regularExpression),
            "Unexpected sentry-trace value: \(value)",
            file: file,
            line: line
        )
    }
}
