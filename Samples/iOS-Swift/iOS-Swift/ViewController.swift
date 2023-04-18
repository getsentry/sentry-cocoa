import Sentry
import UIKit

class ViewController: UIViewController {

    private let dispatchQueue = DispatchQueue(label: "ViewController", attributes: .concurrent)


    override func viewDidLoad() {
        super.viewDidLoad()
        SentrySDK.reportFullyDisplayed()
    }

    @IBAction func uiClickTransaction(_ sender: UIButton) {
        highlightButton(sender)
        dispatchQueue.async {
            if let path = Bundle.main.path(forResource: "LoremIpsum", ofType: "txt") {
                _ = FileManager.default.contents(atPath: path)
            }
        }

        guard let imgUrl = URL(string: "https://sentry-brand.storage.googleapis.com/sentry-logo-black.png") else {
            return
        }
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let dataTask = session.dataTask(with: imgUrl) { (_, _, _) in }
        dataTask.resume()
    }

    var span: Span?
    let profilerNotification = NSNotification.Name("SentryProfileCompleteNotification")
    
    @IBAction func startTransaction(_ sender: UIButton) {
        highlightButton(sender)
        guard span == nil else { return }
        span = SentrySDK.startTransaction(name: "Manual Transaction", operation: "Manual Operation")

        NotificationCenter.default.addObserver(forName: profilerNotification, object: nil, queue: nil) { note in
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Profile completed", message: nil, preferredStyle: .alert)
                alert.addTextField {
                    //swiftlint:disable force_unwrapping
                    $0.text = try! JSONSerialization.data(withJSONObject: note.userInfo!).base64EncodedString()
                    //swiftlint:enable force_unwrapping
                    $0.accessibilityLabel = "io.sentry.ui-tests.profile-marshaling-text-field"
                }
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: false)
            }
        }
    }

    @IBAction func stopTransaction(_ sender: UIButton) {
        highlightButton(sender)
        span?.finish()
        span = nil

        NotificationCenter.default.removeObserver(self, name: profilerNotification, object: nil)
    }

    @IBAction func captureTransaction(_ sender: UIButton) {
        highlightButton(sender)
        let transaction = SentrySDK.startTransaction(name: "Some Transaction", operation: "Some Operation")
        
        transaction.setMeasurement(name: "duration", value: 44, unit: MeasurementUnitDuration.nanosecond)
        transaction.setMeasurement(name: "information", value: 44, unit: MeasurementUnitInformation.bit)
        transaction.setMeasurement(name: "duration-custom", value: 22, unit: MeasurementUnit(unit: "custom"))
        
        let span = transaction.startChild(operation: "user", description: "calls out")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
            span.finish()
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.4...0.6), execute: {
            transaction.finish()
        })
    }

    @IBAction func showNibController(_ sender: UIButton) {
        highlightButton(sender)
        let nib = NibViewController()
        nib.title = "Nib View Controller"
        navigationController?.pushViewController(nib, animated: false)
    }
    
    @IBAction func showTableViewController(_ sender: UIButton) {
        highlightButton(sender)
        let controller = TableViewController(style: .plain)
        controller.title = "Table View Controller"
        navigationController?.pushViewController(controller, animated: false)
    }
    
    @IBAction func useCoreData(_ sender: UIButton) {
        highlightButton(sender)
        let controller = CoreDataViewController()
        controller.title = "CoreData"
        navigationController?.pushViewController(controller, animated: false)
    }

    @IBAction func performanceScenarios(_ sender: UIButton) {
        highlightButton(sender)
        let controller = PerformanceViewController()
        controller.title = "Performance Scenarios"
        navigationController?.pushViewController(controller, animated: false)
    }

    func highlightButton(_ sender: UIButton) {
        let originalLayerColor = sender.layer.backgroundColor
        let originalTitleColor = sender.titleColor(for: .normal)
        sender.layer.backgroundColor = UIColor.blue.cgColor
        sender.setTitleColor(.white, for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            sender.layer.backgroundColor = originalLayerColor
            sender.setTitleColor(originalTitleColor, for: .normal)
            sender.titleLabel?.textColor = originalTitleColor
        }
    }
}
