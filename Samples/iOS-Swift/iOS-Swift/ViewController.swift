import Sentry
import UIKit

class ViewController: UIViewController {

    private let dispatchQueue = DispatchQueue(label: "ViewController", attributes: .concurrent)
    private var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        SentrySDK.reportFullyDisplayed()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        periodicallyDoWork()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super .viewDidDisappear(animated)
        self.timer?.invalidate()
    }
    
    private func periodicallyDoWork() {

        self.timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.dispatchQueue.async {
                self.loadSentryBrandImage()
                Thread.sleep(forTimeInterval: 1.0)
                self.readLoremIpsumFile()
            }
        }
        RunLoop.current.add(self.timer!, forMode: .common)
        self.timer!.fire()
    }

    @IBAction func uiClickTransaction(_ sender: UIButton) {
        highlightButton(sender)
       
        readLoremIpsumFile()
        loadSentryBrandImage()
    }
    
    private func readLoremIpsumFile() {
        dispatchQueue.async {
            if let path = Bundle.main.path(forResource: "LoremIpsum", ofType: "txt") {
                _ = FileManager.default.contents(atPath: path)
            }
        }
    }
    
    private func loadSentryBrandImage() {
        guard let imgUrl = URL(string: "https://sentry-brand.storage.googleapis.com/sentry-logo-black.png") else {
            return
        }
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let dataTask = session.dataTask(with: imgUrl) { (_, _, _) in }
        dataTask.resume()
    }

    var spans = [Span]()
    let profilerNotification = NSNotification.Name("SentryProfileCompleteNotification")

    @IBAction func startTransaction(_ sender: UIButton) {
        highlightButton(sender)
        startNewTransaction()
    }

    fileprivate func startNewTransaction() {
        spans.append(SentrySDK.startTransaction(name: "Manual Transaction", operation: "Manual Operation"))

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

    @IBAction func startTransactionFromOtherThread(_ sender: UIButton) {
        highlightButton(sender)

        Thread.detachNewThread {
            self.startNewTransaction()
        }
    }

    @IBAction func stopTransaction(_ sender: UIButton) {
        highlightButton(sender)

        defer {
            if spans.isEmpty {
                NotificationCenter.default.removeObserver(self, name: profilerNotification, object: nil)
            }
        }

        func showConfirmation(span: Span) {
            DispatchQueue.main.async {
                let confirmation = UIAlertController(title: "Finished span \(span.spanId.sentrySpanIdString)", message: nil, preferredStyle: .alert)
                confirmation.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(confirmation, animated: true)
            }
        }

        func finishSpan(span: Span) {
            span.finish()
            self.spans.remove(at: self.spans.firstIndex(where: { testSpan in
                testSpan.spanId == span.spanId
            })!)
            showConfirmation(span: span)
        }

        if spans.count == 1 {
            finishSpan(span: spans[0])
            return
        }

        let alert = UIAlertController(title: "Choose span to stop", message: nil, preferredStyle: .actionSheet)
        spans.forEach { span in
            alert.addAction(UIAlertAction(title: span.spanId.sentrySpanIdString, style: .default, handler: { _ in
                let threadPicker = UIAlertController(title: "From thread:", message: nil, preferredStyle: .actionSheet)
                threadPicker.addAction(UIAlertAction(title: "Main thread", style: .default, handler: { _ in
                    DispatchQueue.main.async {
                        finishSpan(span: span)
                    }
                }))
                threadPicker.addAction(UIAlertAction(title: "BG thread", style: .default, handler: { _ in
                    Thread.detachNewThread {
                        finishSpan(span: span)
                    }
                }))
                threadPicker.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                self.present(threadPicker, animated: true)
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
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
    
    @IBAction func showPageController(_ sender: UIButton) {
        highlightButton(sender)
        let controller = PageViewController()
        controller.title = "Page View Controller"
        navigationController?.pushViewController(controller, animated: false)
    }
}
