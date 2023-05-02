import Foundation
import Sentry
import UIKit

class UIEventBreadcrumbController: UIViewController {

    private var notificationObserver: NSObjectProtocol?

    @IBOutlet var textField: UITextField!
    @IBOutlet var lastBreadcrumbLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        textField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        textField.addTarget(self, action: #selector(textFieldEndChanging), for: .editingDidEnd)

        notificationObserver = NotificationCenter.default.addObserver(forName: .init("io.sentry.newbreadcrumb"), object: nil, queue: nil) {
            guard let breadcrumb = $0.object as? Breadcrumb else { return }
            if breadcrumb.type != "user" {
                //Ignore non user interaction breadcrumbs
                return
            }
            self.lastBreadcrumbLabel.text = breadcrumb.message ?? "#EMPTY#"
        }
    }

    @objc func textFieldFocus(_ sender: Any) {
    }

    @objc func textFieldEndChanging(_ sender: Any) {
    }

    @objc func textFieldChanged(_ sender: Any) {
    }

    @IBAction func performEditingChangedPressed(_ sender: Any) {
        textField.sendActions(for: .editingChanged)
    }

    @IBAction func perforEditingDidEndPressed(_ sender: Any) {
        textField.sendActions(for: .editingDidEnd)
    }

    override func viewWillDisappear(_ animated: Bool) {
        if let obs = notificationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        super.viewWillDisappear(animated)
    }

}
