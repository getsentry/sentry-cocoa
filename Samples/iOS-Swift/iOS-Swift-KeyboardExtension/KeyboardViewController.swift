import SentrySampleShared
import UIKit

class KeyboardViewController: UIInputViewController {
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        SentrySDKWrapper.shared.startSentry()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        SentrySDKWrapper.shared.startSentry()
    }

    let label: UILabel = {
        let _label = UILabel(frame: .zero)
        _label.translatesAutoresizingMaskIntoConstraints = false
        return _label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
