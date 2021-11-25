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
    
    @objc func assertTransaction() {
        UIAssert.notNil(self.span, "Transaction was not created")
        
        let children = self.span?.children()
        
        UIAssert.isEqual(children?.count, 11, "Transaction did not complete")
        
        spanObserver?.releaseOnFinish()
    }
}
