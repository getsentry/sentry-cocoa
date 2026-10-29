#if compiler(>=6.2)
import SentrySampleShared
import SentrySwift
import SwiftUI
import WebKit

/// Shows the page of ``WebViewController`` in a SwiftUI `WebView`.
@available(iOS 26.0, *)
struct WebPageView: View {
    @State private var page: WebPage?

    var body: some View {
        Group {
            if let page {
                WebView(page)
            } else {
                Color.clear
            }
        }
        .onAppear {
            guard page == nil else { return }
            // Created on appear rather than in init, so the trace is the one of this screen's load.
            let configuration = WebPage.Configuration()
            SentryWebViewTracing.addTracePropagation(
                to: configuration,
                options: SentryWebViewTracingOptions(allowedHosts: [WebViewController.host])
            )
            let page = WebPage(configuration: configuration)
            if let baseURL = URL(string: "https://\(WebViewController.host)/") {
                page.load(html: WebViewController.html(dsn: SentrySDKWrapper.shared.dsn), baseURL: baseURL)
            }
            self.page = page
        }
    }
}
#endif
