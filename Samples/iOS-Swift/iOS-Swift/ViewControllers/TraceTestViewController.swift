import Foundation
import Sentry
import UIKit

class TraceTestViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    var span: Span?
    var spanObserver: SpanObserver?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        
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
                }
            }
        }
        
        dataTask.resume()
        span = SentrySDK.span
        spanObserver = SpanObserver(span: span!.rootSpan()!)
        spanObserver?.performOnFinish {
            self.assertTransaction()
        }
    }
    
    func assertTransaction() {
        guard let span = self.span else {
            UIAssert.fail("Transaction was not created")
            return
        }
        
        guard let children = span.children() else {
            UIAssert.fail("Transaction has no children")
            return
        }
                
        let expectation = 12
        
        UIAssert.isEqual(children.count, expectation, "Transaction did not complete. Expecting \(expectation), got \(children.count)")
        
        guard let child = children.first(where: { $0.context.operation == "http.client" }) else {
            UIAssert.fail("Did not found http request child")
            return
        }
        
        
        UIAssert.isEqual(child.data?["url"] as? String, "/sentry-logo-black.png", "Could not read url data value")
        
        UIAssert.isEqual(child.tags["http.status_code"], "200", "Could not read status_code tag value")
        
        spanObserver?.releaseOnFinish()
        
        UIAssert.hasViewControllerLifeCycle(self.span!, "TraceTestViewController")
    }
}
