#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
import WebKit

private enum SentryWebViewSwizzleKeys {
    static let loadRequest = SentryTypedSwizzle.Key()
    static let loadHTMLString = SentryTypedSwizzle.Key()
    static let loadData = SentryTypedSwizzle.Key()
    static let loadFileURL = SentryTypedSwizzle.Key()
    static let loadFileRequest = SentryTypedSwizzle.Key()
    static let loadSimulatedRequestHTML = SentryTypedSwizzle.Key()
    static let loadSimulatedRequestData = SentryTypedSwizzle.Key()
}

/// Adds trace propagation to every `WKWebView` when ``Options/webViewTracing`` is set.
///
/// Two mechanisms work together:
/// - The `WKWebView` load methods are swizzled to install a fresh script right before each load.
///   Every WebView that shows content goes through one of them, including the one backing a
///   SwiftUI `WebPage`, so this is also how WebViews are discovered. Installing synchronously
///   covers a transaction that starts in the same main-thread pass as the load.
/// - A scope observer re-installs the script on every tracked controller when the trace changes,
///   so navigations that don't go through the load methods, like links, redirects, and reloads,
///   receive the current trace too.
final class SentryWebViewTracePropagationIntegration: NSObject, SwiftIntegration {
    private let refresher: SentryWebViewTraceRefresher

    init?(with options: Options, dependencies: SentryDependencyContainer) {
        guard let webViewTracing = options.webViewTracing else {
            return nil
        }

        guard options.enableSwizzling else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableSwizzling is disabled.")
            return nil
        }

        let allowedHosts = webViewTracing.allowedHosts
        guard allowedHosts.contains(where: { !SentryWebViewTracePropagation.normalizeHost($0).isEmpty }) else {
            SentrySDKLog.warning("Not going to enable \(Self.name) because webViewTracing.allowedHosts has no valid entry.")
            return nil
        }

        refresher = SentryWebViewTraceRefresher(allowedHosts: allowedHosts)

        super.init()

        SentryWebViewTraceRefresherProxy.shared.setTarget(refresher)
        Self.swizzleLoadMethods()

        let observer = SentryWebViewTraceScopeObserver(refresher: refresher)
        SentrySDKInternal.currentHub().configureScope { scope in
            scope.add(observer)
        }
    }

    func uninstall() {
        SentryWebViewTraceRefresherProxy.shared.removeTarget(refresher)
    }

    static var name: String {
        SentryWebViewTracePropagation.integrationName
    }

    /// Process-lifetime swizzles. They forward to the refresher of the current SDK lifecycle and do
    /// nothing once it is gone.
    private static func swizzleLoadMethods() {
        let interceptor: (WKWebView, @escaping () -> AnyObject?) -> AnyObject? = { webView, original in
            willLoad(webView)
            return original()
        }

        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadRequest(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadRequest,
            interceptor: interceptor
        )
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadHTMLString(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadHTMLString,
            interceptor: interceptor
        )
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadData(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadData,
            interceptor: interceptor
        )
        swizzleFileAndSimulatedLoadMethods(interceptor: interceptor)
    }

    private static func swizzleFileAndSimulatedLoadMethods(interceptor: @escaping (WKWebView, @escaping () -> AnyObject?) -> AnyObject?) {
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadFileURL(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadFileURL,
            interceptor: interceptor
        )
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadFileRequest(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadFileRequest,
            interceptor: interceptor
        )
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadSimulatedRequestHTML(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadSimulatedRequestHTML,
            interceptor: interceptor
        )
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadSimulatedRequestData(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadSimulatedRequestData,
            interceptor: interceptor
        )
    }

    /// WebKit requires the main thread for loads. A load from another thread is left to WebKit
    /// rather than touching the controller off the main thread.
    private static func willLoad(_ webView: WKWebView) {
        guard Thread.isMainThread else {
            SentrySDKLog.warning("Not adding WebView trace propagation to a WKWebView load that runs off the main thread.")
            return
        }
        MainActor.assumeIsolated {
            SentryWebViewTraceRefresherProxy.shared.target?.willLoad(webView)
        }
    }
}
#endif
