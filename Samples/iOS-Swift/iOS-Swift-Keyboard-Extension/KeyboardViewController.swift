//
//  KeyboardViewController.swift
//  test-keyboard-extension
//
//  Created by Andrew McKnight on 7/22/25.
//

import Sentry
import UIKit

class KeyboardViewController: UIInputViewController {

    let label: UILabel = {
        let _label = UILabel(frame: .zero)
        _label.translatesAutoresizingMaskIntoConstraints = false
        return _label
    }()
    
    override func viewDidLoad() {
        SentrySDK.start { _ in }

        super.viewDidLoad()

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        label.text = SentrySDK.isEnabled ? "Sentry is enabled" : "Sentry is disabled"
    }
}
