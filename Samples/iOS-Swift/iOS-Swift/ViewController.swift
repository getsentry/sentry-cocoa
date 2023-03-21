import Sentry
import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var dsnTextField: UITextField!
    @IBOutlet weak var anrFullyBlockingButton: UIButton!
    @IBOutlet weak var anrFillingRunLoopButton: UIButton!
    @IBOutlet weak var framesLabel: UILabel!
    @IBOutlet weak var breadcrumbLabel: UILabel!
    
    private let dispatchQueue = DispatchQueue(label: "ViewController", attributes: .concurrent)
    private let diskWriteException = DiskWriteException()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        SentrySDK.configureScope { (scope) in
            scope.setEnvironment("debug")
            scope.setTag(value: "swift", key: "language")
            scope.setExtra(value: String(describing: self), key: "currentViewController")

            let user = User(userId: "1")
            user.email = "tony@example.com"
            scope.setUser(user)
            
            if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg") {
                scope.addAttachment(Attachment(path: path, filename: "Tongariro.jpg", contentType: "image/jpeg"))
            }
            if let data = "hello".data(using: .utf8) {
                scope.addAttachment(Attachment(data: data, filename: "log.txt"))
            }
        }

        // Also works
        let user = User(userId: "1")
        user.email = "tony1@example.com"
        SentrySDK.setUser(user)
        
        dispatchQueue.async {
            let dsn = DSNStorage.shared.getDSN()
            
            DispatchQueue.main.async {
                self.dsnTextField.text = dsn
                self.dsnTextField.backgroundColor = UIColor.systemGreen
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.framesLabel?.text = "Frames Total:\(PrivateSentrySDKOnly.currentScreenFrames.total) Slow:\(PrivateSentrySDKOnly.currentScreenFrames.slow) Frozen:\(PrivateSentrySDKOnly.currentScreenFrames.frozen)"
        }

        SentrySDK.configureScope { (scope) in
            let dict = scope.serialize()

            guard
                let crumbs = dict["breadcrumbs"] as? [[String: Any]],
                let breadcrumb = crumbs.last,
                let data = breadcrumb["data"] as? [String: String]
            else {
                return
            }

            self.breadcrumbLabel?.text = "{ category: \(breadcrumb["category"] ?? "nil"), parentViewController: \(data["parentViewController"] ?? "nil"), beingPresented: \(data["beingPresented"] ?? "nil"), window_isKeyWindow: \(data["window_isKeyWindow"] ?? "nil"), is_window_rootViewController: \(data["is_window_rootViewController"] ?? "nil") }"
        }
    }
    
    @IBAction func addBreadcrumb(_ sender: Any) {
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb)
    }
    
    @IBAction func captureMessage(_ sender: Any) {
        let eventId = SentrySDK.capture(message: "Yeah captured a message")
        // Returns eventId in case of successfull processed event
        // otherwise nil
        print("\(String(describing: eventId))")
    }
    
    @IBAction func uiClickTransaction(_ sender: Any) {
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
    
    @IBAction func captureUserFeedback(_ sender: Any) {
        let error = NSError(domain: "UserFeedbackErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "This never happens."])

        let eventId = SentrySDK.capture(error: error) { scope in
            scope.setLevel(.fatal)
        }
        
        let userFeedback = UserFeedback(eventId: eventId)
        userFeedback.comments = "It broke on iOS-Swift. I don't know why, but this happens."
        userFeedback.email = "john@me.com"
        userFeedback.name = "John Me"
        SentrySDK.capture(userFeedback: userFeedback)
    }
    
    @IBAction func captureError(_ sender: Any) {
        do {
            try RandomErrorGenerator.generate()
        } catch {
            SentrySDK.capture(error: error) { (scope) in
                // Changes in here will only be captured for this event
                // The scope in this callback is a clone of the current scope
                // It contains all data but mutations only influence the event being sent
                scope.setTag(value: "value", key: "myTag")
            }
        }
    }
    
    @IBAction func captureNSException(_ sender: Any) {
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        let scope = Scope()
        scope.setLevel(.fatal)
        // !!!: By explicity just passing the scope, only the data in this scope object will be added to the event; the global scope (calls to configureScope) will be ignored. If you do that, be careful–a lot of useful info is lost. If you just want to mutate what's in the scope use the callback, see: captureError.
        SentrySDK.capture(exception: exception, scope: scope)
    }
    
    @IBAction func captureFatalError(_ sender: Any) {
        fatalError("This is a fatal error. Oh no 😬.")
    }
    
    @IBAction func captureTransaction(_ sender: Any) {
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
   
    @IBAction func crash(_ sender: Any) {
        SentrySDK.crash()
    }

    // swiftlint:disable force_unwrapping
    @IBAction func unwrapCrash(_ sender: Any) {
        let a: String! = nil
        let b: String = a!
        print(b)
    }
    // swiftlint:enable force_unwrapping

    @IBAction func asyncCrash(_ sender: Any) {
        DispatchQueue.main.async {
            self.asyncCrash1()
        }
    }
    
    func asyncCrash1() {
        DispatchQueue.main.async {
            self.asyncCrash2()
        }
    }
    
    func asyncCrash2() {
        DispatchQueue.main.async {
            SentrySDK.crash()
        }
    }

    @IBAction func oomCrash(_ sender: Any) {
        DispatchQueue.main.async {
            let megaByte = 1_024 * 1_024
            let memoryPageSize = NSPageSize()
            let memoryPages = megaByte / memoryPageSize

            while true {
                // Allocate one MB and set one element of each memory page to something.
                let ptr = UnsafeMutablePointer<Int8>.allocate(capacity: megaByte)
                for i in 0..<memoryPages {
                    ptr[i * memoryPageSize] = 40
                }
            }
        }
    }
    
    @IBAction func diskWriteException(_ sender: Any) {
        diskWriteException.continuouslyWriteToDisk()
        
        // As we are writing to disk continuously we would keep adding spans to this UIEventTransaction.
        SentrySDK.span?.finish()
    }
    
    @IBAction func highCPULoad(_ sender: Any) {
        dispatchQueue.async {
            while true {
                _ = self.calcPi()
            }
        }
    }

    @IBAction func start100Threads(_ sender: Any) {
        for _ in 0..<100 {
            Thread.detachNewThread {
                Thread.sleep(forTimeInterval: 10)
            }
        }
    }
    
    private func calcPi() -> Double {
        var denominator = 1.0
        var pi = 0.0
     
        for i in 0..<10_000_000 {
            if i % 2 == 0 {
                pi += 4 / denominator
            } else {
                pi -= 4 / denominator
            }
            
            denominator += 2
        }
        
        return pi
    }

    @IBAction func anrFullyBlocking(_ sender: Any) {
        let buttonTitle = self.anrFullyBlockingButton.currentTitle
        var i = 0
        
        for _ in 0...5_000_000 {
            i += Int.random(in: 0...10)
            i -= 1
            
            self.anrFullyBlockingButton.setTitle("\(i)", for: .normal)
        }
        
        self.anrFullyBlockingButton.setTitle(buttonTitle, for: .normal)
    }
    
    @IBAction func anrFillingRunLoop(_ sender: Any) {
        let buttonTitle = self.anrFillingRunLoopButton.currentTitle
        var i = 0
        
        func sleep(timeout: Double) {
            let group = DispatchGroup()
            group.enter()
            let queue = DispatchQueue(label: "delay", qos: .background, attributes: [])
            
            queue.asyncAfter(deadline: .now() + timeout) {
                group.leave()
            }
            
            group.wait()
        }

        dispatchQueue.async {
            for _ in 0...30 {
                i += Int.random(in: 0...10)
                i -= 1
                
                DispatchQueue.main.async {
                    sleep(timeout: 0.1)
                    self.anrFillingRunLoopButton.setTitle("Title \(i)", for: .normal)
                }
            }
            
            DispatchQueue.main.sync {
                self.anrFillingRunLoopButton.setTitle(buttonTitle, for: .normal)
            }
        }
    }
    
    @IBAction func dsnChanged(_ sender: UITextField) {
        let options = Options()
        options.dsn = sender.text
        
        if let dsn = options.dsn {
            sender.backgroundColor = UIColor.systemGreen
            
            dispatchQueue.async {
                DSNStorage.shared.saveDSN(dsn: dsn)
            }
        } else {
            sender.backgroundColor = UIColor.systemRed
            
            dispatchQueue.async {
                DSNStorage.shared.deleteDSN()
            }
        }
    }
    
    @IBAction func resetDSN(_ sender: Any) {
        self.dsnTextField.text = AppDelegate.defaultDSN
        self.dsnTextField.backgroundColor = UIColor.systemGreen
        
        dispatchQueue.async {
            DSNStorage.shared.saveDSN(dsn: AppDelegate.defaultDSN)
        }
    }
    
    @IBAction func showNibController(_ sender: Any) {
        let nib = NibViewController()
        nib.title = "Nib View Controller"
        navigationController?.pushViewController(nib, animated: false)
    }
    
    @IBAction func showTableViewController(_ sender: Any) {
        let controller = TableViewController(style: .plain)
        controller.title = "Table View Controller"
        navigationController?.pushViewController(controller, animated: false)
    }
    
    @IBAction func useCoreData(_ sender: Any) {
        let controller = CoreDataViewController()
        controller.title = "CoreData"
        navigationController?.pushViewController(controller, animated: false)
    }

    @IBAction func performanceScenarios(_ sender: Any) {
        let controller = PerformanceViewController()
        controller.title = "Performance Scenarios"
        navigationController?.pushViewController(controller, animated: false)
    }

    @IBAction func permissions(_ sender: Any) {
        let controller = PermissionsViewController()
        controller.title = "Permissions"
        navigationController?.pushViewController(controller, animated: true)
    }
    
    @IBAction func flush(_ sender: Any) {
        SentrySDK.flush(timeout: 5)
    }
    
    @IBAction func close(_ sender: Any) {
        SentrySDK.close()
    }
    
    @IBAction func startSDK(_ sender: Any) {
        AppDelegate.startSentry()
    }
}
