import Foundation
import Sentry
import UIKit

class InfoForBreadcrumbController: UIViewController {

    @IBOutlet var button: UIButton!
    @IBOutlet var label: UILabel!

    @IBAction func buttonPressed(_ sender: Any) {
        guard let view = self.view,
              let viewInfo = SentryBreadcrumbTracker.extractData(from: view),
              let buttonInfo = SentryBreadcrumbTracker.extractData(from: button)
        else {
            label?.text = "ERROR"
            return
        }

        let hasCorrectData = String(describing: view) == viewInfo["view"] as! String &&
        viewInfo["tag"] == nil &&
        viewInfo["accessibilityIdentifier"] as? String == "SOME IDENTIFIER" &&
        viewInfo["title"] == nil &&
        buttonInfo["tag"] as? Int == 1 &&
        buttonInfo["accessibilityIdentifier"] as? String == "extractInfoButton" &&
        buttonInfo["title"] as? String == button.title(for: .normal)

        label?.text = hasCorrectData ? [viewInfo, buttonInfo].debugDescription : "ERROR"
    }
}
