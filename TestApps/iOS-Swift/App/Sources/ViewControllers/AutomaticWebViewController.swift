@_spi(Private) import SentrySwift
import SentrySampleShared
import UIKit
import WebKit

/// Shows the page of ``WebViewController`` without calling `SentryWebViewTracing`, so the trace
/// only arrives when `options.webViewTracing` is set. Launch with
/// `--io.sentry.webview.enable-automatic-tracing` to enable it.
///
/// Pages are served by a custom scheme handler under the sample host, so the in-page link loads a
/// second page without network access.
class AutomaticWebViewController: UIViewController {

    static let scheme = "sentry-sample"

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(PageHandler(), forURLScheme: Self.scheme)
        return WKWebView(frame: .zero, configuration: configuration)
    }()

    override func loadView() {
        self.view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Automatic"
        if let url = URL(string: "\(Self.scheme)://\(WebViewController.host)/") {
            webView.load(URLRequest(url: url))
        }
    }

    private final class PageHandler: NSObject, WKURLSchemeHandler {
        func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
            guard let url = urlSchemeTask.request.url else {
                return
            }
            let html = WebViewController.html(dsn: SentrySDK.startOption?.dsn, showsNextPageLink: true)
            let data = Data(html.utf8)
            urlSchemeTask.didReceive(URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "utf-8"))
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
    }
}
