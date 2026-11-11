#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import WebKit
import XCTest

@MainActor
final class SentryWebViewTraceRefresherTests: XCTestCase {

    private var originalHub: SentryHubInternal!
    private var scope: Scope!

    override func setUp() {
        super.setUp()
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryWebViewTraceRefresherTests")
        options.removeAllIntegrations()
        originalHub = SentrySDKInternal.currentHub()
        scope = Scope()
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: SentryClientInternal(options: options), andScope: scope))
    }

    override func tearDown() {
        SentrySDKInternal.setCurrentHub(originalHub)
        super.tearDown()
    }

    func testWillLoad_whenControllerTrackedByManualCall_shouldKeepItsHosts() throws {
        // -- Arrange --
        let refresher = SentryWebViewTraceRefresher(allowedHosts: ["example.com"], hubProvider: { SentrySDKInternal.currentHub() })
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let controller = webView.configuration.userContentController
        refresher.track(controller, allowedHosts: ["other.com"])

        // -- Act --
        refresher.willLoad(webView)

        // -- Assert --
        XCTAssertEqual(refresher.trackedHosts(for: controller), ["other.com"])
        let source = try XCTUnwrap(controller.sentryScripts.first?.source)
        XCTAssertTrue(source.contains("[\"other.com\"]"))
    }

    func testRefreshAll_whenTraceChanged_shouldInstallNewTrace() throws {
        // -- Arrange --
        let refresher = SentryWebViewTraceRefresher(allowedHosts: ["example.com"], hubProvider: { SentrySDKInternal.currentHub() })
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        refresher.willLoad(webView)
        let newTraceId = SentryId()
        scope.propagationContext = SentryPropagationContext(traceId: newTraceId, spanId: SpanId())

        // -- Act --
        refresher.refreshAll()

        // -- Assert --
        let scripts = webView.configuration.userContentController.sentryScripts
        XCTAssertEqual(scripts.count, 1)
        XCTAssertEqual(scripts.first?.source.contains(newTraceId.sentryIdString), true)
    }

    func testTrack_shouldNotRetainController() {
        // -- Arrange --
        let refresher = SentryWebViewTraceRefresher(allowedHosts: ["example.com"], hubProvider: { nil })
        weak var weakController: WKUserContentController?

        // -- Act --
        autoreleasepool {
            let controller = WKUserContentController()
            weakController = controller
            refresher.track(controller, allowedHosts: ["example.com"])
        }

        // -- Assert --
        XCTAssertNil(weakController)
    }
}
#endif
