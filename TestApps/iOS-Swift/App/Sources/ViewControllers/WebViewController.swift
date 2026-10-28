import Foundation
import SentrySwift
import WebKit

class WebViewController: UIViewController {

    // Served under this host so the page receives the injected trace.
    private static let host = "webview.sentry-sample.local"

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
        // A page using @sentry/browser would continue this trace on pageload. This one only shows
        // the injected tags, so no web SDK or network access is needed.
        let html = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <script>
        function content(name) {
          var meta = document.querySelector('meta[name="' + name + '"]');
          return meta ? meta.content : 'not injected';
        }
        window.addEventListener('DOMContentLoaded', function() {
          document.getElementById('sentry-trace').textContent = content('sentry-trace');
          document.getElementById('baggage').textContent = content('baggage');
        });
        </script>
        </head>
        <body style="font-family: -apple-system; padding: 16px; word-break: break-all;">
        <h3>sentry-trace</h3><p id="sentry-trace"></p>
        <h3>baggage</h3><p id="baggage"></p>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://\(Self.host)/"))
    }
}
