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

/// Tracks the user content controllers that receive trace propagation and keeps their script
/// current.
final class SentryWebViewTraceRefresher {
    private let allowedHosts: [String]
    private let hubProvider: () -> SentryHubInternal?

    /// Maps each tracked controller to its allowed hosts. Keys are weak, so tracking never keeps a
    /// WebView's controller alive. Only accessed on the main actor.
    private let controllers = NSMapTable<WKUserContentController, NSArray>(
        keyOptions: .weakMemory,
        valueOptions: .strongMemory
    )

    init(
        allowedHosts: [String],
        hubProvider: @escaping () -> SentryHubInternal? = { SentryWebViewTracePropagation.currentHub }
    ) {
        self.allowedHosts = allowedHosts
        self.hubProvider = hubProvider
    }

    /// Installs a fresh script right before the WebView loads, tracking its controller with the
    /// app-wide hosts unless ``SentryWebViewTracing`` already tracks it with its own.
    @MainActor
    func willLoad(_ webView: WKWebView) {
        let controller = webView.configuration.userContentController
        let hosts: [String]
        if let trackedHosts = trackedHosts(for: controller) {
            hosts = trackedHosts
        } else {
            hosts = allowedHosts
            track(controller, allowedHosts: hosts)
        }
        SentryWebViewTracePropagation.install(allowedHosts: hosts, on: controller, hub: hubProvider())
    }

    /// Tracks a controller that ``SentryWebViewTracing`` configured, so its own hosts are kept on
    /// later loads and refreshes.
    @MainActor
    func track(_ controller: WKUserContentController, allowedHosts: [String]) {
        controllers.setObject(allowedHosts as NSArray, forKey: controller)
    }

    /// Re-installs the script with the current trace on every tracked controller.
    @MainActor
    func refreshAll() {
        let hub = hubProvider()
        for controller in trackedControllers() {
            guard let hosts = trackedHosts(for: controller) else {
                continue
            }
            SentryWebViewTracePropagation.install(allowedHosts: hosts, on: controller, hub: hub)
        }
    }

    /// The tracked controllers that are still alive.
    @MainActor
    func trackedControllers() -> [WKUserContentController] {
        controllers.keyEnumerator().allObjects.compactMap { $0 as? WKUserContentController }
    }

    @MainActor
    func trackedHosts(for controller: WKUserContentController) -> [String]? {
        controllers.object(forKey: controller) as? [String]
    }
}

/// Routes the process-lifetime swizzles and ``SentryWebViewTracing`` to the refresher of the
/// current SDK lifecycle.
final class SentryWebViewTraceRefresherProxy {
    private final class WeakBox {
        weak var value: SentryWebViewTraceRefresher?

        init(_ value: SentryWebViewTraceRefresher) {
            self.value = value
        }
    }

    static let shared = SentryWebViewTraceRefresherProxy()

    private let weakTargetMutex = SentryMutex<WeakBox?>(nil)

    var target: SentryWebViewTraceRefresher? {
        weakTargetMutex.withLock { $0?.value }
    }

    func setTarget(_ target: SentryWebViewTraceRefresher) {
        let reference = WeakBox(target)
        weakTargetMutex.withLock { $0 = reference }
    }

    func removeTarget(_ target: SentryWebViewTraceRefresher) {
        weakTargetMutex.withLock {
            // An older integration must not remove a newer integration's refresher.
            guard $0?.value === target else {
                return
            }
            $0 = nil
        }
    }
}

/// Refreshes the tracked WebViews when the scope's span or propagation context changes.
///
/// The scope calls observers synchronously from any thread while holding its locks, so the refresh
/// is dispatched to the main actor, and changes that arrive before it runs are coalesced into one.
final class SentryWebViewTraceScopeObserver: NSObject, SentryScopeObserver {
    private weak var refresher: SentryWebViewTraceRefresher?
    private let scheduleOnMain: (@escaping () -> Void) -> Void
    private let isRefreshScheduled = SentryMutex(false)

    init(
        refresher: SentryWebViewTraceRefresher,
        scheduleOnMain: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }
    ) {
        self.refresher = refresher
        self.scheduleOnMain = scheduleOnMain
    }

    func setTraceContext(_ traceContext: [String: Any]?) {
        scheduleRefresh()
    }

    func clear() {
        scheduleRefresh()
    }

    func setUser(_ user: User?) {}
    func setTags(_ tags: [String: String]?) {}
    func setExtras(_ extras: [String: Any]?) {}
    func setContext(_ context: [String: [String: Any]]?) {}
    func setDist(_ dist: String?) {}
    func setEnvironment(_ environment: String?) {}
    func setFingerprint(_ fingerprint: [String]?) {}
    func setLevel(_ level: SentryLevel) {}
    func setAttributes(_ attributes: [String: Any]?) {}
    func addSerializedBreadcrumb(_ serializedBreadcrumb: [String: Any]) {}
    func clearBreadcrumbs() {}

    private func scheduleRefresh() {
        let shouldSchedule = isRefreshScheduled.withLock { isScheduled -> Bool in
            guard !isScheduled else {
                return false
            }
            isScheduled = true
            return true
        }
        guard shouldSchedule else {
            return
        }

        scheduleOnMain { [weak self] in
            guard let self = self else {
                return
            }
            self.isRefreshScheduled.withLock { $0 = false }
            MainActor.assumeIsolated {
                self.refresher?.refreshAll()
            }
        }
    }
}
#endif
