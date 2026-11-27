#if !SDK_V10
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import Foundation
import SentrySampleShared
import SwiftUI
import WebKit

class WebViewController: UIViewController {

    // Served under this host so the page receives the injected trace.
    static let host = SentrySDKWrapper.webViewHost

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        SentryWebViewTracing.addTracePropagation(
            to: configuration,
            options: SentryWebViewTracingOptions(allowedHosts: [Self.host])
        )
        return WKWebView(frame: .zero, configuration: configuration)
    }()

    override func loadView() {
        self.view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.loadHTMLString(Self.html(dsn: SentrySDK.startOption?.dsn), baseURL: URL(string: "https://\(Self.host)/"))

        let automaticButton = UIBarButtonItem(title: "Auto", primaryAction: UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(AutomaticWebViewController(), animated: true)
        })
        automaticButton.accessibilityIdentifier = "webview-automatic"

        let existingButton = UIBarButtonItem(title: "Existing", primaryAction: UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(ExistingWebViewController(), animated: true)
        })
        existingButton.accessibilityIdentifier = "webview-existing"
        navigationItem.rightBarButtonItems = [automaticButton, existingButton]

#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let swiftUIButton = UIBarButtonItem(title: "SwiftUI", primaryAction: UIAction { [weak self] _ in
                let controller = UIHostingController(rootView: WebPageView())
                controller.title = "WebPage"
                self?.navigationController?.pushViewController(controller, animated: true)
            })
            swiftUIButton.accessibilityIdentifier = "webview-swiftui"
            navigationItem.rightBarButtonItems?.append(swiftUIButton)
        }
#endif
    }

    /// The trace the SDK propagates right now, read from the scope so UI tests can compare it with
    /// the injected tags.
    private static var nativeTraceId: String {
        let scope = SentrySDKInternal.currentHub().scope
        return (scope.span?.traceId ?? scope.propagationContextTraceId).sentryIdString
    }

    /// The page runs `@sentry/browser`, which continues the injected trace on pageload. It also
    /// shows the injected tags, read before any page script could add them, so UI tests can check
    /// the injection without network access.
    ///
    /// With `showsNextPageLink`, the page links to another page of the same host. Following it is a
    /// navigation inside the page that doesn't go through a `WKWebView` load method.
    static func html(dsn: String?, showsNextPageLink: Bool = false) -> String {
        let dsnLiteral = dsn.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.fragmentsAllowed]) }
            .flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script>
        // The first page script. Sentry's document-start script runs before it, so the tags exist.
        function content(name) {
          var meta = document.querySelector('meta[name="' + name + '"]');
          return meta ? meta.content : 'not injected';
        }
        window.injected = { trace: content('sentry-trace'), baggage: content('baggage') };
        </script>
        <script src="https://browser.sentry-cdn.com/11.6.0/bundle.tracing.min.js" crossorigin="anonymous"></script>
        <script>
        // browserTracingIntegration reads the injected tags on pageload and continues the trace.
        // Guarded so the page still shows the tags when the CDN script can't load.
        var dsn = \(dsnLiteral);
        if (window.Sentry && dsn) {
          Sentry.init({
            dsn: dsn,
            integrations: [Sentry.browserTracingIntegration()],
            tracesSampleRate: 1.0,
            release: 'webview-demo',
            environment: 'webview'
          });
        }
        </script>
        </head>
        <body style="font-family: -apple-system; padding: 16px; word-break: break-all;">
        <p>native-trace: \(nativeTraceId)</p>
        <h3>sentry-trace</h3><p id="sentry-trace"></p>
        <h3>baggage</h3><p id="baggage"></p>
        \(showsNextPageLink ? "<p id=\"page\"></p><p><a href=\"/next\">Next page</a></p>" : "")
        <script>
        document.getElementById('sentry-trace').textContent = 'sentry-trace: ' + window.injected.trace;
        document.getElementById('baggage').textContent = window.injected.baggage;
        var page = document.getElementById('page');
        if (page) { page.textContent = 'page: ' + window.location.pathname; }
        </script>
        </body>
        </html>
        """
    }
}
