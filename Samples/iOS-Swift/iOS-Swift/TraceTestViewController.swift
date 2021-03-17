import Foundation
import Sentry
import UIKit

class TraceTestViewController: UIViewController {
    
    var loadSpan: Span?
    @IBOutlet weak var imageView: UIImageView!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        initialize()
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    private func initialize() {
        //Start a transaction to determine how long it take to display the view.
        loadSpan = SentrySDK.startTransaction(name: "TraceTestViewController", operation: "navigation")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let child = loadSpan?.startChild(operation: "network")
        guard let imgUrl = URL(string: "https://sentry-brand.storage.googleapis.com/sentry-logo-black.png") else {
            return
        }
        
        let dataTask = URLSession.shared.dataTask(with: imgUrl) { (data, _, error) in
            DispatchQueue.main.async {
                var spanStatus = SentrySpanStatus.ok
                if let err = error {
                    SentrySDK.capture(error: err)
                    spanStatus = .unknownError
                } else if let image = data {
                    self.imageView.image = UIImage(data: image)
                }
                child?.finish(status: spanStatus)
                self.loadSpan?.finish()
            }
        }
        dataTask.resume()
    }
}
