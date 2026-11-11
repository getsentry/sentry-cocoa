#if !SDK_V10
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import UIKit
import WebKit

/// Shows the page of ``WebViewController``, adding trace propagation to a web view that already
/// exists instead of to its configuration before creating it.
class ExistingWebViewController: UIViewController {

    private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

    override func loadView() {
        self.view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Existing"
        SentryWebViewTracing.addTracePropagation(
            to: webView,
            options: SentryWebViewTracingOptions(allowedHosts: [WebViewController.host])
        )
        webView.loadHTMLString(
            WebViewController.html(dsn: SentrySDK.startOption?.dsn),
            baseURL: URL(string: "https://\(WebViewController.host)/")
        )
    }
}
