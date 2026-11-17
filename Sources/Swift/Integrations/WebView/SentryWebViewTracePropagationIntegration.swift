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
    static let reload = SentryTypedSwizzle.Key()
    static let reloadFromOrigin = SentryTypedSwizzle.Key()
}

typealias SentryWebViewTracePropagationIntegrationDependencies = HubProvider & DispatchQueueWrapperProvider

/// Adds trace propagation to every `WKWebView` when ``Options/webViewTracing`` is set.
///
/// Two mechanisms work together:
/// - The `WKWebView` load and reload methods are swizzled to install a fresh script right before
///   each load. Every WebView that shows content goes through a load method, including the one
///   backing a SwiftUI `WebPage`, so this is also how WebViews are discovered. Installing
///   synchronously covers a trace change in the same main-thread pass as the load or reload.
/// - A scope observer re-installs the script on every tracked controller when the trace changes,
///   so navigations that don't go through these methods, like links and redirects, receive the
///   current trace too.
final class SentryWebViewTracePropagationIntegration<Dependencies: SentryWebViewTracePropagationIntegrationDependencies>: NSObject, SwiftIntegration {
    private let refresher: SentryWebViewTraceRefresher
    private let dispatchQueue: SentryDispatchQueueWrapper

    init?(with options: Options, dependencies: Dependencies) {
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
        dispatchQueue = dependencies.dispatchQueueWrapper

        super.init()

        SentryWebViewTraceRefresherProxy.shared.setTarget(refresher)
        Self.swizzleLoadMethods()

        let observer = SentryWebViewTraceScopeObserver(refresher: refresher, dispatchQueue: dispatchQueue)
        dependencies.hub.configureScope { scope in
            scope.add(observer)
        }
    }

    func uninstall() {
        SentryWebViewTraceRefresherProxy.shared.removeTarget(refresher)
        // The scripts carry the last trace, so remove them. WebKit requires the main thread.
        let refresher = refresher
        dispatchQueue.dispatchAsyncOnMainQueueIfNotMainThread {
            refresher.removeAll()
        }
    }

    static var name: String {
        SentryWebViewTracePropagation.integrationName
    }

    /// Process-lifetime swizzles. They forward to the refresher of the current SDK lifecycle and do
    /// nothing once it is gone.
    private static func swizzleLoadMethods() {
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadRequest(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadRequest
        ) { webView, request, original in
            willLoad(webView)
            return original(request)
        }
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadHTMLString(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadHTMLString
        ) { webView, string, baseURL, original in
            willLoad(webView)
            return original(string, baseURL)
        }
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadData(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadData
        ) { webView, data, mimeType, characterEncodingName, baseURL, original in
            willLoad(webView)
            return original(data, mimeType, characterEncodingName, baseURL)
        }
        swizzleFileAndSimulatedLoadMethods()
        swizzleReloadMethods()
    }

    private static func swizzleFileAndSimulatedLoadMethods() {
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadFileURL(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadFileURL
        ) { webView, url, readAccessURL, original in
            willLoad(webView)
            return original(url, readAccessURL)
        }
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadFileRequest(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadFileRequest
        ) { webView, request, readAccessURL, original in
            willLoad(webView)
            return original(request, readAccessURL)
        }
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadSimulatedRequestHTML(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadSimulatedRequestHTML
        ) { webView, request, html, original in
            willLoad(webView)
            return original(request, html)
        }
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewLoadSimulatedRequestData(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.loadSimulatedRequestData
        ) { webView, request, response, data, original in
            willLoad(webView)
            return original(request, response, data)
        }
    }

    /// A reload doesn't go through a load method. Installing synchronously covers a trace change in
    /// the same main-thread pass as the reload, which the scope observer's refresh can be too late for.
    private static func swizzleReloadMethods() {
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewReload(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.reload
        ) { webView, original in
            willLoad(webView)
            return original()
        }
        SentryTypedSwizzle.instanceMethod(
            in: WKWebView.self,
            method: .webViewReloadFromOrigin(WKWebView.self),
            mode: .oncePerClassAndSuperclasses,
            key: SentryWebViewSwizzleKeys.reloadFromOrigin
        ) { webView, original in
            willLoad(webView)
            return original()
        }
    }

    /// WebKit requires the main thread for loads. A load from another thread is left to WebKit
    /// rather than touching the controller off the main thread.
    private static func willLoad(_ webView: WKWebView) {
        guard Thread.isMainThread else {
            SentrySDKLog.warning("Not adding WebView trace propagation to a WKWebView load that runs off the main thread.")
            return
        }
        SentryWebViewTraceRefresherProxy.shared.target?.willLoad(webView)
    }
}
#endif
