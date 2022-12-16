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
            DispatchQueue.main.async {
                if let err = error {
                    SentrySDK.capture(error: err)
                } else if let image = data {
                    self.imageView.image = UIImage(data: image)
                    self.appendLifeCycleStep("GET https://sentry-brand.storage.googleapis.com/sentry-logo-black.png")
                }
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

            guard let child = children.first(where: { $0.operation == "http.client" }) else {
                UIAssert.fail("Did not found http request child")
                return
            }

            UIAssert.isEqual(child.data["url"] as? String, "/sentry-logo-black.png", "Could not read url data value")

            UIAssert.isEqual(child.tags["http.status_code"], "200", "Could not read status_code tag value")

            UIAssert.checkForViewControllerLifeCycle(span, viewController: "TraceTestViewController", stepsToCheck: self.lifeCycleSteps)
        }
    }
}
