import Foundation
import Sentry
import UIKit

class TraceTestViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    var spanObserver: SpanObserver?
    var lifeCycleSteps = ["loadView"]
    var addSpan = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        appendLifeCycleStep("viewDidLoad")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let imgUrl = URL(string: "https://sentry-brand.storage.googleapis.com/sentry-logo-black.png") else {
            return
        }
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let dataTask = session.dataTask(with: imgUrl) { (data, _, error) in
            //Simulated delay in the download
            DispatchQueue.main.async {
                if let err = error {
                    SentrySDK.capture(error: err)
                } else if let image = data {
                    self.imageView.image = UIImage(data: image)
                    self.appendLifeCycleStep("GET https://sentry-brand.storage.googleapis.com/sentry-logo-black.png")
                }
                SentrySDK.reportFullyDisplayed()
            }
        }
        
        dataTask.resume()
        spanObserver = createTransactionObserver(forCallback: assertTransaction)
        appendLifeCycleStep("viewWillAppear")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appendLifeCycleStep("viewDidAppear")
        addSpan = false
    }
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        appendLifeCycleStep("viewWillLayoutSubviews")
        appendLifeCycleStep("layoutSubViews")
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        appendLifeCycleStep("viewDidLayoutSubviews")
    }
    
    func appendLifeCycleStep(_ name: String) {
        if addSpan {
            lifeCycleSteps.append(name)
        }
    }
    
    func assertTransaction(span: Span) {
        DispatchQueue.main.async {
            self.spanObserver?.releaseOnFinish()
            guard let children = span.children() else {
                UIAssert.fail("Transaction has no children")
                return
            }

            guard let child = children.first(where: { $0.operation == "http.client" && $0.data["url"] as? String == "https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" && $0.data["http.response.status_code"] as? String == "200" }) else {
                UIAssert.fail("Did not find child span for HTTP for retrieving the sentry brand logo.")
                return
            }

            UIAssert.checkForViewControllerLifeCycle(span, viewController: "TraceTestViewController", stepsToCheck: self.lifeCycleSteps)
        }
    }
}
