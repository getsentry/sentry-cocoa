import Foundation
import WebKit

class WebViewController: UIViewController {
    
    let webView = WKWebView()
    
    override func loadView() {
        self.view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = URL(string: "https://sentry.io") {
            webView.load(URLRequest(url: url))
        }
    }
}
