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
        loadSpan = SentrySDK.startTransaction(name: "TraceTestViewController", operation: "UI")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        loadSpan?.startChild(name: "Download Image", operation: "network")
        
        let dataTask = URLSession.shared.dataTask(with: URL(string: "https://yt3.ggpht.com/ytc/AAUvwnieYkenrDwzJI8dWcpbC1EetcymN5EZJx4MLsH3=s900-c-k-c0x00ffffff-no-rj")!) { (data, _, error) in
            DispatchQueue.main.async {
                if let err = error {
                    SentrySDK.capture(error: err)
                } else if let image = data {
                    self.imageView.image = UIImage(data: image)
                }
                self.loadSpan?.finish()
            }
        }
        dataTask.resume()
    }
}
