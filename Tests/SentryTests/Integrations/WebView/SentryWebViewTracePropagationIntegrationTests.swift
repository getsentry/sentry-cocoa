#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import SwiftUI
import WebKit
import XCTest

@MainActor
final class SentryWebViewTracePropagationIntegrationTests: XCTestCase {

    private let options: Options = {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryWebViewTracePropagationIntegrationTests")
        options.releaseName = "app@1.0.0"
        options.environment = "test"
        options.removeAllIntegrations()
        options.enableSwizzling = true
        options.webViewTracing = SentryWebViewTracingOptions(allowedHosts: ["example.com"])
        return options
    }()

    private var originalHub: SentryHubInternal!
    private var scope: Scope!
    private var sut: SentryWebViewTracePropagationIntegration?

    override func setUp() {
        super.setUp()
        originalHub = SentrySDKInternal.currentHub()
        scope = Scope()
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: SentryClientInternal(options: options), andScope: scope))
    }

    override func tearDown() {
        // The swizzles live for the process, so the refresher must be removed for the next tests.
        sut?.uninstall()
        sut = nil
        SentrySDKInternal.setCurrentHub(originalHub)
        super.tearDown()
    }

    // MARK: - Installation

    func testInit_whenWebViewTracingNotSet_shouldNotInstall() {
        // -- Arrange --
        options.webViewTracing = nil

        // -- Act --
        let integration = SentryWebViewTracePropagationIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())

        // -- Assert --
        XCTAssertNil(integration)
        XCTAssertNil(SentryWebViewTraceRefresherProxy.shared.target)
    }

    func testInit_whenSwizzlingDisabled_shouldNotInstall() {
        // -- Arrange --
        options.enableSwizzling = false

        // -- Act --
        let integration = SentryWebViewTracePropagationIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())

        // -- Assert --
        XCTAssertNil(integration)
    }

    func testInit_whenNoValidAllowedHosts_shouldNotInstall() {
        // -- Arrange --
        options.webViewTracing = SentryWebViewTracingOptions(allowedHosts: ["", "  ", "https://"])

        // -- Act --
        let integration = SentryWebViewTracePropagationIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance())

        // -- Assert --
        XCTAssertNil(integration)
    }

    func testName_shouldMatchManualUsageName() {
        XCTAssertEqual(SentryWebViewTracePropagationIntegration.name, "SentryWebViewTracePropagationIntegration")
    }

    func testUninstall_shouldStopInstallingOnLoad() throws {
        // -- Arrange --
        let integration = try install()
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

        // -- Act --
        integration.uninstall()
        webView.loadHTMLString("", baseURL: URL(string: "https://example.com/"))

        // -- Assert --
        XCTAssertNil(SentryWebViewTraceRefresherProxy.shared.target)
        XCTAssertTrue(webView.configuration.userContentController.userScripts.isEmpty)
    }

    // MARK: - Swizzled load methods

    func testLoadRequest_shouldInstallScriptBeforeLoad() throws {
        try assertInstallsScript { webView in
            webView.load(URLRequest(url: try XCTUnwrap(URL(string: "about:blank"))))
        }
    }

    func testLoadHTMLString_shouldInstallScriptBeforeLoad() throws {
        try assertInstallsScript { webView in
            webView.loadHTMLString("", baseURL: URL(string: "https://example.com/"))
        }
    }

    func testLoadData_shouldInstallScriptBeforeLoad() throws {
        try assertInstallsScript { webView in
            webView.load(Data(), mimeType: "text/html", characterEncodingName: "utf-8", baseURL: try XCTUnwrap(URL(string: "https://example.com/")))
        }
    }

    func testLoadFileURL_shouldInstallScriptBeforeLoad() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name.hashValue).html")
        try Data().write(to: fileURL)
        addTeardownBlock { try FileManager.default.removeItem(at: fileURL) }

        try assertInstallsScript { webView in
            webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL)
        }
    }

    func testLoadFileRequest_shouldInstallScriptBeforeLoad() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name.hashValue).html")
        try Data().write(to: fileURL)
        addTeardownBlock { try FileManager.default.removeItem(at: fileURL) }

        try assertInstallsScript { webView in
            webView.loadFileRequest(URLRequest(url: fileURL), allowingReadAccessTo: fileURL)
        }
    }

    func testLoadSimulatedRequestHTML_shouldInstallScriptBeforeLoad() throws {
        try assertInstallsScript { webView in
            webView.loadSimulatedRequest(URLRequest(url: try XCTUnwrap(URL(string: "https://example.com/"))), responseHTML: "")
        }
    }

    func testLoadSimulatedRequestData_shouldInstallScriptBeforeLoad() throws {
        try assertInstallsScript { webView in
            let url = try XCTUnwrap(URL(string: "https://example.com/"))
            let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: 0, textEncodingName: "utf-8")
            webView.loadSimulatedRequest(URLRequest(url: url), response: response, responseData: Data())
        }
    }

    func testLoad_whenWebViewSubclass_shouldInstallScriptBeforeLoad() throws {
        // -- Arrange --
        try install()
        let webView = WebViewSubclass(frame: .zero, configuration: WKWebViewConfiguration())

        // -- Act --
        webView.loadHTMLString("", baseURL: URL(string: "https://example.com/"))

        // -- Assert --
        XCTAssertEqual(webView.configuration.userContentController.sentryScripts.count, 1)
    }

#if compiler(>=6.2)
    func testLoad_whenWebPage_shouldInstallScriptBeforeLoad() throws {
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("WebPage requires iOS 26, macOS 26 or visionOS 26.")
        }
        // -- Arrange --
        try install()
        let configuration = WebPage.Configuration()
        let page = WebPage(configuration: configuration)

        // -- Act --
        // `WebPage` loads through a private `WKWebView` subclass. This fails if it stops doing so.
        _ = page.load(html: "", baseURL: try XCTUnwrap(URL(string: "https://example.com/")))

        // -- Assert --
        XCTAssertEqual(configuration.userContentController.sentryScripts.count, 1)
    }

    func testLoad_whenSwiftUIWebViewWithURL_shouldTrackItsController() throws {
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("SwiftUI WebView requires iOS 26, macOS 26 or visionOS 26.")
        }
        // Mac Catalyst unit tests run without an NSApplication, and creating a UIWindow without one
        // throws an uncaught exception that ends the test process.
        if ProcessInfo.processInfo.isMacCatalystApp {
            throw XCTSkip("Mac Catalyst unit tests can't create a window.")
        }
        // -- Arrange --
        try install()
        let refresher = try XCTUnwrap(SentryWebViewTraceRefresherProxy.shared.target)
        let url = try XCTUnwrap(URL(string: "https://example.com/"))

        // -- Act --
        // `WebView(url:)` creates its `WebPage` internally, so the app can't pass a configuration.
        let window = showInWindow(WebView(url: url).frame(width: 100, height: 100))
        defer { withExtendedLifetime(window) {} }
        let deadline = Date().addingTimeInterval(10)
        while refresher.trackedControllers().isEmpty && Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }

        // -- Assert --
        let controller = try XCTUnwrap(refresher.trackedControllers().first, "The WebView didn't load through a swizzled method.")
        XCTAssertEqual(controller.sentryScripts.count, 1)
    }
#endif

    // MARK: - Manual API

    func testAddTracePropagation_whenIntegrationInstalled_shouldTrackControllerWithItsHosts() throws {
        // -- Arrange --
        try install()
        let controller = WKUserContentController()

        // -- Act --
        SentryWebViewTracing.addTracePropagation(to: controller, options: .init(allowedHosts: ["other.com"]))

        // -- Assert --
        let refresher = try XCTUnwrap(SentryWebViewTraceRefresherProxy.shared.target)
        XCTAssertEqual(refresher.trackedHosts(for: controller), ["other.com"])
    }

    // MARK: - Page loads

    // Pages come from a custom scheme handler, so no network is needed. The host is allowed, so the
    // script injects the trace like it would for an https page.

    func testNavigation_whenTraceChangesBeforeInPageNavigation_shouldInjectNewTrace() throws {
        // -- Arrange --
        try install()
        let page = PageLoader()
        try page.load { try $0.load(URLRequest(url: XCTUnwrap(URL(string: "sentry-test://app.example.com/a")))) }
        XCTAssertEqual(try page.seenTraceId(), scope.propagationContextTraceId.sentryIdString)
        let newTraceId = changeTrace()

        // -- Act --
        try page.load { $0.evaluateJavaScript("location.href = 'sentry-test://app.example.com/b'; true") }

        // -- Assert --
        XCTAssertEqual(page.webView.url?.path, "/b")
        XCTAssertEqual(try page.seenTraceId(), newTraceId)
    }

    func testNavigation_whenTraceChangesBeforeReload_shouldInjectNewTrace() throws {
        // -- Arrange --
        try install()
        let page = PageLoader()
        try page.load { try $0.load(URLRequest(url: XCTUnwrap(URL(string: "sentry-test://app.example.com/a")))) }
        let newTraceId = changeTrace()

        // -- Act --
        try page.load { $0.reload() }

        // -- Assert --
        XCTAssertEqual(try page.seenTraceId(), newTraceId)
    }

    /// The refresh runs on the next main-queue turn, but its script update still reaches the web
    /// content process before the reloaded document is created, so a reload in the same turn as the
    /// trace change gets the new trace. Repeated because the outcome depends on WebKit's ordering.
    func testNavigation_whenTraceChangesInSameTurnAsReload_shouldInjectNewTrace() throws {
        // -- Arrange --
        try install()
        let page = PageLoader()
        try page.load { try $0.load(URLRequest(url: XCTUnwrap(URL(string: "sentry-test://app.example.com/a")))) }

        for _ in 0..<10 {
            let traceId = SentryId()

            // -- Act --
            scope.propagationContext = SentryPropagationContext(traceId: traceId, spanId: SpanId())
            try page.load { $0.reload() }

            // -- Assert --
            XCTAssertEqual(try page.seenTraceId(), traceId.sentryIdString)
        }
    }

    /// WebKit restores the previous page from its back/forward cache without running any script, so
    /// neither our script nor the Browser SDK's pageload runs again, and the page keeps its trace.
    func testNavigation_whenGoingBackToCachedPage_shouldKeepItsOriginalTrace() throws {
        // -- Arrange --
        try install()
        let page = PageLoader()
        try page.load { try $0.load(URLRequest(url: XCTUnwrap(URL(string: "sentry-test://app.example.com/a")))) }
        let firstTraceId = try page.seenTraceId()
        _ = try page.evaluate("window.marker = 'a'; true")
        try page.load { $0.evaluateJavaScript("location.href = 'sentry-test://app.example.com/b'; true") }
        changeTrace()

        // -- Act --
        try page.load { $0.goBack() }

        // -- Assert --
        XCTAssertEqual(page.webView.url?.path, "/a")
        XCTAssertEqual(try page.evaluate("window.marker || null") as? String, "a")
        XCTAssertEqual(try page.seenTraceId(), firstTraceId)
    }

    // MARK: - Helpers

    @discardableResult
    private func install() throws -> SentryWebViewTracePropagationIntegration {
        let integration = try XCTUnwrap(SentryWebViewTracePropagationIntegration(with: options, dependencies: SentryDependencyContainer.sharedInstance()))
        sut = integration
        return integration
    }

    /// Installs the integration, calls a load method on a new WebView, and checks that the script
    /// was installed synchronously, before the load started.
    private func assertInstallsScript(file: StaticString = #filePath, line: UInt = #line, _ load: (WKWebView) throws -> Void) throws {
        // -- Arrange --
        try install()
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let controller = webView.configuration.userContentController
        controller.addUserScript(WKUserScript(source: "window.app = 1;", injectionTime: .atDocumentStart, forMainFrameOnly: true))

        // -- Act --
        try load(webView)

        // -- Assert --
        XCTAssertEqual(controller.sentryScripts.count, 1, file: file, line: line)
        XCTAssertEqual(controller.userScripts.last?.source, "window.app = 1;", file: file, line: line)
        let refresher = try XCTUnwrap(SentryWebViewTraceRefresherProxy.shared.target, file: file, line: line)
        XCTAssertEqual(refresher.trackedHosts(for: controller), ["example.com"], file: file, line: line)
    }

    /// Starts a new trace and waits for the scope observer's refresh, which runs on the next main
    /// queue turn.
    @discardableResult
    private func changeTrace() -> String {
        let traceId = SentryId()
        scope.propagationContext = SentryPropagationContext(traceId: traceId, spanId: SpanId())
        let refreshed = expectation(description: "Refreshed")
        DispatchQueue.main.async { refreshed.fulfill() }
        wait(for: [refreshed], timeout: 5)
        return traceId.sentryIdString
    }

#if compiler(>=6.2)
    /// Shows a SwiftUI view in a window, so SwiftUI creates and loads its content.
    private func showInWindow<Content: View>(_ content: Content) -> AnyObject {
#if os(macOS)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: content)
        window.orderFront(nil)
        return window
#else
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.rootViewController = UIHostingController(rootView: content)
        window.isHidden = false
        return window
#endif
    }
#endif
}

private final class WebViewSubclass: WKWebView {}

/// Loads pages served by ``PageSchemeHandler`` and waits for each navigation to finish.
@MainActor
private final class PageLoader: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private var onFinish: ((Error?) -> Void)?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(PageSchemeHandler(), forURLScheme: "sentry-test")
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
    }

    /// Starts a navigation and waits until it finishes.
    func load(file: StaticString = #filePath, line: UInt = #line, _ start: (WKWebView) throws -> Void) throws {
        var finished = false
        var navigationError: Error?
        onFinish = { error in
            navigationError = error
            finished = true
        }
        try start(webView)
        let deadline = Date().addingTimeInterval(30)
        while !finished && Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        onFinish = nil
        XCTAssertTrue(finished, "Navigation did not finish", file: file, line: line)
        XCTAssertNil(navigationError, file: file, line: line)
    }

    /// The trace ID of the `sentry-trace` tag that the page's first script saw.
    func seenTraceId() throws -> String? {
        (try evaluate("window.seenTrace || null") as? String)?.components(separatedBy: "-").first
    }

    func evaluate(_ script: String) throws -> Any? {
        var result: Any?
        var done = false
        webView.evaluateJavaScript(script) { value, _ in
            result = value
            done = true
        }
        let deadline = Date().addingTimeInterval(30)
        while !done && Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return result
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onFinish?(nil)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onFinish?(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onFinish?(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        onFinish?(NSError(domain: "WebContentProcessDidTerminate", code: 0))
    }
}

/// Serves a page whose first script stores the `sentry-trace` tag it sees.
private final class PageSchemeHandler: NSObject, WKURLSchemeHandler {
    private let html = "<html><head><script>window.seenTrace = (document.querySelector('meta[name=\"sentry-trace\"]') || {}).content;</script></head></html>"

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            return
        }
        let data = Data(html.utf8)
        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8"))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
#endif
