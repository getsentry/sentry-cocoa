import UIKit

let fontSize: CGFloat = 12

func addDSNDisplay(_ vc: UIViewController, vcview: UIView) {
    let dsnVC = DSNDisplayViewController(nibName: nil, bundle: nil)
    vcview.addSubview(dsnVC.view)
    dsnVC.view.matchEdgeAnchors(from: vcview)
    vc.addChild(dsnVC)
}

class DSNDisplayViewController: UIViewController {
    let dispatchQueue = DispatchQueue(label: "io.sentry.iOS-Swift.queue.dsn-management", attributes: .concurrent)
    let label = UILabel(frame: .zero)
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemFill
        } else {
            view.backgroundColor = .lightGray.withAlphaComponent(0.5)
        }
        
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.textAlignment = .center
        
        let changeButton = UIButton(type: .roundedRect)
        changeButton.setTitle("Change", for: .normal)
        changeButton.addTarget(self, action: #selector(changeDSN), for: .touchUpInside)
        
        let resetButton = UIButton(type: .roundedRect)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.addTarget(self, action: #selector(resetDSN), for: .touchUpInside)
        
        let buttonStack = UIStackView(arrangedSubviews: [
            changeButton,
            resetButton
        ])
        buttonStack.axis = .vertical
        buttonStack.distribution = .fillEqually
        
        let stack = UIStackView(arrangedSubviews: [
            label,
            buttonStack
        ])
        
        view.addSubview(stack)
        stack.matchEdgeAnchors(from: view, leadingPad: 20)
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.3).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateDSNLabel()
    }
    
    @objc func dsnChanged(_ newDSN: String) {
        let options = Options()
        options.dsn = newDSN

        if let dsn = options.dsn {
            dispatchQueue.async {
                do {
                    try DSNStorage.shared.saveDSN(dsn: dsn)
                    DispatchQueue.main.async {
                        showToast(in: self, type: .success, message: "DSN changed!")
                    }
                } catch {
                    SentrySDK.capture(error: error)
                    DispatchQueue.main.async {
                        showToast(in: self, type: .error, message: error.localizedDescription)
                    }
                }
                DispatchQueue.main.async {
                    self.updateDSNLabel()
                }
            }
        } else {
            showToast(in: self, type: .warning, message: "Invalid DSN, reverting to the default.")
            self.dispatchQueue.async {
                do {
                    try DSNStorage.shared.deleteDSN()
                } catch {
                    SentrySDK.capture(error: error)
                    DispatchQueue.main.async {
                        showToast(in: self, type: .error, message: error.localizedDescription)
                    }
                }
                DispatchQueue.main.async {
                    self.updateDSNLabel()
                }
            }
        }
    }
    
    @objc func changeDSN() {
        let alert = UIAlertController(title: "Change DSN", message: nil, preferredStyle: .alert)
        var configuredTextField: UITextField?
        alert.addTextField { textField in
            configuredTextField = textField
        }
        alert.addAction(.init(title: "Save", style: .default, handler: { _ in
            guard let dsn = configuredTextField?.text else {
                return
            }
            self.dsnChanged(dsn)
        }))
        alert.addAction(.init(title: "Cancel", style: .destructive))
        present(alert, animated: true)
    }

    @objc func resetDSN() {
        self.dispatchQueue.async {
            do {
                try DSNStorage.shared.deleteDSN()
                DispatchQueue.main.async {
                    showToast(in: self, type: .success, message: "DSN reset to default!")
                }
            } catch {
                SentrySDK.capture(error: error)
                DispatchQueue.main.async {
                    showToast(in: self, type: .error, message: "Failed to reset DSN: \(error)")
                }
            }
            DispatchQueue.main.async {
                self.updateDSNLabel()
            }
        }
    }
    
    func updateDSNLabel() {
        do {
            let dsn = try DSNStorage.shared.getDSN() ?? AppDelegate.defaultDSN
            self.label.attributedText = dsnFieldTitleString(dsn: dsn)
        } catch {
            SentrySDK.capture(error: error)
            DispatchQueue.main.async {
                showToast(in: self, type: .error, message: "Failed to read DSN: \(error)")
            }
        }
    }
    
    func dsnFieldTitleString(dsn: String) -> NSAttributedString {
        let defaultAnnotation = "(default)"
        let overriddenAnnotation = "(overridden)"
        guard dsn != AppDelegate.defaultDSN else {
            let title = "DSN \(defaultAnnotation):"
            let stringContents = "\(title): \(dsn)"
            let attributedString = NSMutableAttributedString(string: stringContents)
            attributedString.setAttributes([.font: UIFont.boldSystemFont(ofSize: fontSize)], range: (stringContents as NSString).range(of: title))
            attributedString.setAttributes([.font: UIFont.systemFont(ofSize: fontSize)], range: (stringContents as NSString).range(of: dsn))
            return attributedString
        }
        
        let title = "DSN \(overriddenAnnotation)"
        let stringContents = "\(title): \(dsn)"
        let attributedString = NSMutableAttributedString(string: stringContents)
        
        // attributes are stacked as last-one-wins since ranges overlap
        attributedString.setAttributes([.font: UIFont.boldSystemFont(ofSize: fontSize)], range: (stringContents as NSString).range(of: title))
        attributedString.setAttributes([.foregroundColor: UIColor.red, .font: UIFont.boldSystemFont(ofSize: fontSize)], range: (stringContents as NSString).range(of: overriddenAnnotation))
        
        attributedString.setAttributes([.font: UIFont.systemFont(ofSize: fontSize)], range: (stringContents as NSString).range(of: dsn))
        return attributedString
    }
}
