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
final class SentryWebViewTraceScopeObserverTests: XCTestCase {

    private var originalHub: SentryHubInternal!
    private var scope: Scope!

    override func setUp() {
        super.setUp()
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryWebViewTraceScopeObserverTests")
        options.removeAllIntegrations()
        originalHub = SentrySDKInternal.currentHub()
        scope = Scope()
        SentrySDKInternal.setCurrentHub(SentryHubInternal(client: SentryClientInternal(options: options), andScope: scope))
    }

    override func tearDown() {
        SentrySDKInternal.setCurrentHub(originalHub)
        super.tearDown()
    }

    func testScopeObserver_whenTraceChangesTwiceBeforeRefresh_shouldRefreshOnce() throws {
        // -- Arrange --
        let refresher = SentryWebViewTraceRefresher(allowedHosts: ["example.com"], hubProvider: { SentrySDKInternal.currentHub() })
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        refresher.willLoad(webView)
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        dispatchQueue.dispatchAsyncOnMainQueueExecutesBlock = false
        let observer = SentryWebViewTraceScopeObserver(refresher: refresher, dispatchQueue: dispatchQueue)
        scope.add(observer)
        let newTraceId = SentryId()

        // -- Act --
        scope.propagationContext = SentryPropagationContext(traceId: SentryId(), spanId: SpanId())
        scope.propagationContext = SentryPropagationContext(traceId: newTraceId, spanId: SpanId())
        XCTAssertEqual(dispatchQueue.dispatchAsyncOnMainQueueInvocations.count, 1)
        dispatchQueue.dispatchAsyncOnMainQueueInvocations.invocations.forEach { $0() }

        // -- Assert --
        let source = try XCTUnwrap(webView.configuration.userContentController.sentryScripts.first?.source)
        XCTAssertTrue(source.contains(newTraceId.sentryIdString))
    }

    func testScopeObserver_whenTraceChangesAfterRefresh_shouldScheduleAgain() {
        // -- Arrange --
        let refresher = SentryWebViewTraceRefresher(allowedHosts: ["example.com"], hubProvider: { nil })
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        dispatchQueue.dispatchAsyncOnMainQueueExecutesBlock = false
        let observer = SentryWebViewTraceScopeObserver(refresher: refresher, dispatchQueue: dispatchQueue)

        // -- Act --
        observer.setTraceContext(nil)
        dispatchQueue.dispatchAsyncOnMainQueueInvocations.first?()
        observer.setTraceContext(nil)

        // -- Assert --
        XCTAssertEqual(dispatchQueue.dispatchAsyncOnMainQueueInvocations.count, 2)
    }
}
#endif
