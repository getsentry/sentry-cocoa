#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import JavaScriptCore
import WebKit
import XCTest

@MainActor
final class SentryWebViewTracingTests: XCTestCase {

    private let options: Options = {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryWebViewTracingTests")
        options.releaseName = "app@1.0.0"
        options.environment = "test"
        return options
    }()

    // MARK: - normalizeHost

    func testNormalizeHost_whenEntryHasExtras_shouldReturnBareLowercaseHost() {
        // -- Arrange --
        let cases: [(input: String, expected: String)] = [
            ("example.com", "example.com"),
            (" https://App.Example.com:8080/x?y#z ", "app.example.com"),
            ("example.com.", "example.com"),
            ("custom-scheme://example.com", "example.com"),
            ("192.168.0.1:8080", "192.168.0.1"),
            ("::1", "[::1]"),
            ("[::1]:8080", "[::1]"),
            ("[2001:DB8::1]", "[2001:db8::1]"),
            ("*.Example.com", "example.com"),
            ("https://*.example.com/", "example.com"),
            ("   ", "")
        ]

        for (input, expected) in cases {
            // -- Act --
            let result = SentryWebViewTracePropagation.normalizeHost(input)

            // -- Assert --
            XCTAssertEqual(result, expected, "Input: \(input)")
        }
    }

    // MARK: - makeScriptSource

    func testMakeScriptSource_whenNoValidHosts_shouldReturnNil() {
        // -- Arrange --
        let hub = WebViewTestHub(options: options, scope: Scope())

        // -- Act --
        let source = SentryWebViewTracePropagation.makeScriptSource(allowedHosts: ["", "  "], hub: hub)

        // -- Assert --
        XCTAssertNil(source)
    }

    func testMakeScriptSource_whenSDKNotEnabled_shouldReturnNil() {
        // -- Act --
        let source = SentryWebViewTracePropagation.makeScriptSource(allowedHosts: ["example.com"], hub: nil)

        // -- Assert --
        XCTAssertNil(source)
    }

    func testMakeScriptSource_whenNoActiveSpan_shouldOmitSampledFlag() throws {
        // -- Arrange --
        let scope = Scope()
        let hub = WebViewTestHub(options: options, scope: scope)
        let propagationHeader = scope.propagationContextTraceHeader

        // -- Act --
        let source = try XCTUnwrap(SentryWebViewTracePropagation.makeScriptSource(allowedHosts: ["example.com"], hub: hub))
        let tags = try evaluate(source, host: "example.com")

        // -- Assert --
        XCTAssertEqual(
            tags["sentry-trace"],
            "\(propagationHeader.traceId.sentryIdString)-\(propagationHeader.spanId.sentrySpanIdString)"
        )
        let baggage = try XCTUnwrap(tags["baggage"])
        let entries = SentryBaggageSerialization.decode(baggage)
        XCTAssertEqual(entries["sentry-trace_id"], propagationHeader.traceId.sentryIdString)
        XCTAssertEqual(entries["sentry-release"], "app@1.0.0")
        XCTAssertEqual(entries["sentry-environment"], "test")
    }

    func testMakeScriptSource_whenSpanActive_shouldUseSpanAndStripTransaction() throws {
        // -- Arrange --
        let scope = Scope()
        let sentryHub = SentryHubInternal(client: SentryClientInternal(options: options), andScope: scope)
        let tracer = SentryTracer(
            transactionContext: TransactionContext(name: "/user/jane@example.com", operation: "ui.load", sampled: .yes, sampleRate: nil, sampleRand: nil),
            hub: sentryHub
        )
        scope.span = tracer
        let hub = WebViewTestHub(options: options, scope: scope)

        // -- Act --
        let source = try XCTUnwrap(SentryWebViewTracePropagation.makeScriptSource(allowedHosts: ["example.com"], hub: hub))
        let tags = try evaluate(source, host: "example.com")

        // -- Assert --
        XCTAssertEqual(tags["sentry-trace"], tracer.toTraceHeader().value())
        let baggage = try XCTUnwrap(tags["baggage"])
        let entries = SentryBaggageSerialization.decode(baggage)
        XCTAssertEqual(entries["sentry-trace_id"], tracer.traceId.sentryIdString)
        XCTAssertEqual(entries["sentry-sampled"], "true")
        XCTAssertNil(entries["sentry-transaction"])
        XCTAssertFalse(source.contains("jane@example.com"))
    }

    // MARK: - Injected script

    func testScript_whenHostIsSubdomain_shouldInjectTags() throws {
        // -- Arrange --
        let source = try makeSource(allowedHosts: ["Example.com"])

        // -- Act --
        let tags = try evaluate(source, host: "app.example.com")

        // -- Assert --
        XCTAssertNotNil(tags["sentry-trace"])
        XCTAssertNotNil(tags["baggage"])
    }

    func testScript_whenHostNotAllowed_shouldNotInjectTags() throws {
        // -- Arrange --
        let source = try makeSource(allowedHosts: ["example.com"])

        // -- Act --
        let tags = try evaluate(source, host: "evilexample.com")

        // -- Assert --
        XCTAssertTrue(tags.isEmpty)
    }

    func testScript_whenSentryTraceTagExists_shouldNotInjectTags() throws {
        // -- Arrange --
        let source = try makeSource(allowedHosts: ["example.com"])

        // -- Act --
        let tags = try evaluate(source, host: "example.com", hasExistingSentryTraceTag: true)

        // -- Assert --
        XCTAssertTrue(tags.isEmpty)
    }

    func testScript_whenInSubframe_shouldNotInjectTags() throws {
        // -- Arrange --
        let source = try makeSource(allowedHosts: ["example.com"])

        // -- Act --
        let tags = try evaluate(source, host: "example.com", isTopFrame: false)

        // -- Assert --
        XCTAssertTrue(tags.isEmpty)
    }

    func testMakeScriptSource_whenHostsRepeat_shouldListEachHostOnce() throws {
        // -- Act --
        let source = try makeSource(allowedHosts: ["example.com", "EXAMPLE.com", "*.example.com"])

        // -- Assert --
        XCTAssertTrue(source.contains("var allowed=[\"example.com\"];"))
    }

    // MARK: - install

    func testInstall_shouldAddMainFrameScriptAtDocumentStartBeforeAppScripts() throws {
        // -- Arrange --
        let controller = WKUserContentController()
        let appScript = WKUserScript(source: "window.app = 1;", injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        controller.addUserScript(appScript)
        let hub = WebViewTestHub(options: options, scope: Scope())

        // -- Act --
        let installed = SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: controller, hub: hub)

        // -- Assert --
        XCTAssertTrue(installed)
        XCTAssertEqual(controller.userScripts.count, 2)
        let sentryScript = try XCTUnwrap(controller.userScripts.element(at: 0))
        XCTAssertTrue(sentryScript.source.hasPrefix(SentryWebViewTracePropagation.scriptMarker))
        XCTAssertEqual(sentryScript.injectionTime, .atDocumentStart)
        XCTAssertTrue(sentryScript.isForMainFrameOnly)
        XCTAssertEqual(controller.userScripts.element(at: 1)?.source, appScript.source)
    }

    func testInstall_whenCalledTwice_shouldKeepOneSentryScript() {
        // -- Arrange --
        let controller = WKUserContentController()
        let hub = WebViewTestHub(options: options, scope: Scope())

        // -- Act --
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: controller, hub: hub)
        SentryWebViewTracePropagation.install(allowedHosts: ["example.org"], on: controller, hub: hub)

        // -- Assert --
        XCTAssertEqual(controller.userScripts.count, 1)
        XCTAssertEqual(controller.userScripts.first?.source.contains("example.org"), true)
    }

    func testInstall_whenSDKNotEnabled_shouldRemoveSentryScript() {
        // -- Arrange --
        let controller = WKUserContentController()
        let hub = WebViewTestHub(options: options, scope: Scope())
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: controller, hub: hub)

        // -- Act --
        let installed = SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: controller, hub: nil)

        // -- Assert --
        XCTAssertFalse(installed)
        XCTAssertTrue(controller.userScripts.isEmpty)
    }

    func testInstall_whenNoValidHosts_shouldRemoveSentryScriptAndKeepAppScripts() {
        // -- Arrange --
        let controller = WKUserContentController()
        let hub = WebViewTestHub(options: options, scope: Scope())
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: controller, hub: hub)
        controller.addUserScript(WKUserScript(source: "window.app = 1;", injectionTime: .atDocumentEnd, forMainFrameOnly: false))

        // -- Act --
        let installed = SentryWebViewTracePropagation.install(allowedHosts: [" "], on: controller, hub: hub)

        // -- Assert --
        XCTAssertFalse(installed)
        XCTAssertEqual(controller.userScripts.map(\.source), ["window.app = 1;"])
    }

    func testInstall_whenCalledAgainAfterTraceChanged_shouldInjectNewTrace() throws {
        // -- Arrange --
        let controller = WKUserContentController()
        let scope = Scope()
        let hub = WebViewTestHub(options: options, scope: scope)
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: controller, hub: hub)
        let newTraceId = SentryId()
        scope.propagationContext = SentryPropagationContext(traceId: newTraceId, spanId: SpanId())

        // -- Act --
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: controller, hub: hub)

        // -- Assert --
        XCTAssertEqual(controller.userScripts.count, 1)
        let source = try XCTUnwrap(controller.userScripts.first?.source)
        let tags = try evaluate(source, host: "example.com")
        XCTAssertEqual(tags["sentry-trace"]?.hasPrefix(newTraceId.sentryIdString), true)
    }

    // MARK: - Integration tracking

    func testRecordUsage_whenCalledTwice_shouldAddIntegrationOnce() {
        // -- Arrange --
        let hub = SentryHubInternal(client: nil, andScope: nil)

        // -- Act --
        SentryWebViewTracePropagation.recordUsage(in: hub)
        SentryWebViewTracePropagation.recordUsage(in: hub)

        // -- Assert --
        XCTAssertEqual(hub.installedIntegrationNames(), ["SentryWebViewTracePropagationIntegration"])
        XCTAssertEqual(hub.installedIntegrations().count, 1)
    }

    // MARK: - Public API

    // The SDK isn't started in these tests, so a public call removes the script installed through
    // the test hub. That proves each overload reaches the expected user content controller.

    func testAddTracePropagation_whenSDKNotEnabled_shouldReturnFalseAndRemoveScriptFromController() {
        // -- Arrange --
        let controller = WKUserContentController()
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: controller, hub: WebViewTestHub(options: options, scope: Scope()))

        // -- Act --
        let installed = SentryWebViewTracing.addTracePropagation(to: controller, options: .init(allowedHosts: ["example.com"]))

        // -- Assert --
        XCTAssertFalse(installed)
        XCTAssertTrue(controller.userScripts.isEmpty)
    }

    func testAddTracePropagation_whenConfiguration_shouldUseItsUserContentController() {
        // -- Arrange --
        let configuration = WKWebViewConfiguration()
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: configuration.userContentController, hub: WebViewTestHub(options: options, scope: Scope()))

        // -- Act --
        SentryWebViewTracing.addTracePropagation(to: configuration, options: .init(allowedHosts: ["example.com"]))

        // -- Assert --
        XCTAssertTrue(configuration.userContentController.userScripts.isEmpty)
    }

    func testAddTracePropagation_whenWebView_shouldUseItsUserContentController() {
        // -- Arrange --
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let controller = webView.configuration.userContentController
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: controller, hub: WebViewTestHub(options: options, scope: Scope()))

        // -- Act --
        SentryWebViewTracing.addTracePropagation(to: webView, options: .init(allowedHosts: ["example.com"]))

        // -- Assert --
        XCTAssertTrue(controller.userScripts.isEmpty)
    }

#if compiler(>=6.2)
    func testAddTracePropagation_whenWebPageConfiguration_shouldUseItsUserContentController() throws {
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("WebPage requires iOS 26, macOS 26 or visionOS 26.")
        }
        // -- Arrange --
        let configuration = WebPage.Configuration()
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: configuration.userContentController, hub: WebViewTestHub(options: options, scope: Scope()))

        // -- Act --
        SentryWebViewTracing.addTracePropagation(to: configuration, options: .init(allowedHosts: ["example.com"]))

        // -- Assert --
        XCTAssertTrue(configuration.userContentController.userScripts.isEmpty)
    }
#endif

    // MARK: - WKWebView

    func testInstall_whenAddedAfterWebViewCreated_shouldInjectTagsOnNextNavigation() throws {
        // -- Arrange --
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let navigationDelegate = NavigationDelegate()
        webView.navigationDelegate = navigationDelegate
        let scope = Scope()
        let hub = WebViewTestHub(options: options, scope: scope)
        let expectedTraceId = scope.propagationContextTraceId.sentryIdString

        // -- Act --
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: webView.configuration.userContentController, hub: hub)
        let loaded = expectation(description: "Page loaded")
        var navigationError: Error?
        navigationDelegate.onFinish = { error in
            navigationError = error
            loaded.fulfill()
        }
        webView.loadHTMLString(seenTraceHTML, baseURL: URL(string: "https://app.example.com/"))
        wait(for: [loaded], timeout: 30)
        XCTAssertNil(navigationError)

        // -- Assert --
        let evaluated = expectation(description: "Script evaluated")
        var seenTrace: String?
        webView.evaluateJavaScript("window.seenTrace") { result, _ in
            seenTrace = result as? String
            evaluated.fulfill()
        }
        wait(for: [evaluated], timeout: 30)
        XCTAssertEqual(seenTrace?.hasPrefix(expectedTraceId), true)
    }

#if compiler(>=6.2)
    func testInstall_whenWebPageCreatedWithConfiguration_shouldInjectTagsBeforePageScripts() async throws {
        guard #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) else {
            throw XCTSkip("WebPage requires iOS 26, macOS 26 or visionOS 26.")
        }
        // -- Arrange --
        let configuration = WebPage.Configuration()
        let scope = Scope()
        let hub = WebViewTestHub(options: options, scope: scope)
        let expectedTraceId = scope.propagationContextTraceId.sentryIdString
        SentryWebViewTracePropagation.install(allowedHosts: ["example.com"], on: configuration.userContentController, hub: hub)
        let page = WebPage(configuration: configuration)

        // -- Act --
        let baseURL = try XCTUnwrap(URL(string: "https://app.example.com/"))
        for try await event in page.load(html: seenTraceHTML, baseURL: baseURL) where event == .finished {
            break
        }
        let seenTrace = try await page.callJavaScript("return window.seenTrace") as? String

        // -- Assert --
        XCTAssertEqual(seenTrace?.hasPrefix(expectedTraceId), true)
    }
#endif

    // MARK: - Helpers

    /// A page whose first script stores the `sentry-trace` tag it sees, proving the tags exist before
    /// page scripts run.
    private let seenTraceHTML = "<html><head><script>window.seenTrace = (document.querySelector('meta[name=\"sentry-trace\"]') || {}).content;</script></head></html>"

    private func makeSource(allowedHosts: [String]) throws -> String {
        let hub = WebViewTestHub(options: options, scope: Scope())
        return try XCTUnwrap(SentryWebViewTracePropagation.makeScriptSource(allowedHosts: allowedHosts, hub: hub))
    }

    /// Runs the injected script against a minimal DOM stub and returns the `<meta>` tags it wrote.
    private func evaluate(_ source: String, host: String, hasExistingSentryTraceTag: Bool = false, isTopFrame: Bool = true) throws -> [String: String] {
        let context = try XCTUnwrap(JSContext())
        context.setObject(host, forKeyedSubscript: "stubHost" as NSString)
        context.setObject(hasExistingSentryTraceTag, forKeyedSubscript: "stubHasTag" as NSString)
        context.setObject(isTopFrame, forKeyedSubscript: "stubIsTopFrame" as NSString)
        context.evaluateScript("""
        var metas = {};
        var window = { location: { hostname: stubHost } };
        window.top = stubIsTopFrame ? window : {};
        var document = {
          head: { appendChild: function(m) { metas[m.attrs.name] = m.attrs.content; } },
          querySelector: function() { return stubHasTag ? {} : null; },
          createElement: function() { var attrs = {}; return { attrs: attrs, setAttribute: function(k, v) { attrs[k] = v; } }; }
        };
        """)
        context.evaluateScript(source)
        XCTAssertNil(context.exception)
        return try XCTUnwrap(context.objectForKeyedSubscript("metas").toDictionary() as? [String: String])
    }
}

private final class NavigationDelegate: NSObject, WKNavigationDelegate {
    /// Called with `nil` when the navigation finishes, or with the error that ended it.
    var onFinish: ((Error?) -> Void)?

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

private final class WebViewTestHub: Hub {
    let currentOptions: Options?
    let scope: Scope

    init(options: Options, scope: Scope) {
        currentOptions = options
        self.scope = scope
    }

    var options: Options {
        currentOptions ?? Options()
    }

    func configureScope(_ callback: @escaping (Scope) -> Void) {
        callback(scope)
    }

    func storeEnvelope(_ envelope: SentryEnvelope) {}
    func captureEnvelope(_ envelope: SentryEnvelope) {}
    func captureNonTerminatingEnvelope(_ envelope: SentryEnvelope) {}
    func updateSessionForDroppedEventNonTerminating(unhandled: Bool) {}
    func captureErrorEvent(event: Event) {}
    func captureErrorEvent(event: Event, hint: Hint) {}
    func setTrace(_ traceId: SentryId, spanId: SpanId) {}
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    func getSessionReplayId() -> String? { nil }
#endif
}
#endif
