import Foundation

class SRRedactSampleViewController: UIViewController {
    
    @IBOutlet var notRedactedView: UIView!
    @IBOutlet var notRedactedLabel: UILabel!
    
    @IBOutlet var label: UILabel!
    
    private let animatedLabel: UILabel = {
        let label = UILabel()
        label.text = "Animated"
        label.sizeToFit()
        return label
    }()
    
    private var continueAnimating = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        notRedactedView.backgroundColor = .green
        notRedactedView.transform = CGAffineTransform(rotationAngle: 45 * .pi / 180.0)
        SentrySDK.replay.unmaskView(notRedactedLabel)
        
        animatedLabel.frame = CGRect(origin: .zero, size: animatedLabel.frame.size)
        view.addSubview(animatedLabel)
        animate()
    
    }
    
    func inspectViewLayer() {
        guard let layer = view.layer.presentation() else {
            print("### No presentation layer")
            return
        }
        
        layer.sublayers?.forEach { sublayer in
            print("### Sublayer: \(sublayer.delegate)")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        continueAnimating = false
    }
    
    private func animate() {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.repeat, .autoreverse], animations: { [weak self] in
            guard let self = self else { return }
            self.animatedLabel.frame = CGRect(
                origin: CGPoint(x: 0, y: self.view.frame.height),
                size: self.animatedLabel.frame.size)
        })
    }
}
