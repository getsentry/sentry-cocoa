#if canImport(WebKit) && (os(iOS) || os(macOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
internal import _SentryPrivate
import WebKit

/// Tracks the user content controllers that receive trace propagation and keeps their script
/// current.
final class SentryWebViewTraceRefresher {
    private let allowedHosts: [String]
    private let hubProvider: () -> SentryHubInternal?

    /// Maps each tracked controller to its allowed hosts. Keys are weak, so tracking never keeps a
    /// WebView's controller alive. Only accessed on the main thread.
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
    func track(_ controller: WKUserContentController, allowedHosts: [String]) {
        controllers.setObject(allowedHosts as NSArray, forKey: controller)
    }

    /// Re-installs the script with the current trace on every tracked controller.
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
    func trackedControllers() -> [WKUserContentController] {
        controllers.keyEnumerator().allObjects.compactMap { $0 as? WKUserContentController }
    }

    func trackedHosts(for controller: WKUserContentController) -> [String]? {
        controllers.object(forKey: controller) as? [String]
    }
}
#endif
