import Foundation

class SRRedactSampleViewController: UIViewController {
    
    @IBOutlet var notRedactedView: UIView!
    @IBOutlet var notRedactedLabel: UILabel!
    
    @IBOutlet var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        notRedactedView.backgroundColor = .green
        notRedactedView.transform = CGAffineTransform(rotationAngle: 45 * .pi / 180.0)
        SentrySDK.replay.unmaskView(notRedactedLabel)
      }
}
