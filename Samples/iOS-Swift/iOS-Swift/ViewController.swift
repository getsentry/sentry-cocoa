import Sentry
import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var dsnTextField: UITextField!
    @IBOutlet weak var anrFullyBlockingButton: UIButton!
    @IBOutlet weak var anrFillingRunLoopButton: UIButton!
    @IBOutlet weak var framesLabel: UILabel!
    
    private let dispatchQueue = DispatchQueue(label: "ViewController")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        SentrySDK.configureScope { (scope) in
            scope.setEnvironment("debug")
            scope.setTag(value: "swift", key: "language")
            scope.setExtra(value: String(describing: self), key: "currentViewController")
            let user = Sentry.User(userId: "1")
            user.email = "tony@example.com"
            scope.setUser(user)
            
            if let path = Bundle.main.path(forResource: "Tongariro", ofType: "jpg") {
                scope.add(Attachment(path: path, filename: "Tongariro.jpg", contentType: "image/jpeg"))
            }
            if let data = "hello".data(using: .utf8) {
                scope.add(Attachment(data: data, filename: "log.txt"))
            }
            
        }
        // Also works
        let user = Sentry.User(userId: "1")
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
        if #available(iOS 10.0, *) {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                self.framesLabel.text = "Frames Total:\(PrivateSentrySDKOnly.currentScreenFrames.total) Slow:\(PrivateSentrySDKOnly.currentScreenFrames.slow) Frozen:\(PrivateSentrySDKOnly.currentScreenFrames.frozen)"
            }
        }
    }
    
    @IBAction func addBreadcrumb(_ sender: Any) {
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb: crumb)
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
        // By explicity just passing the scope, only the data in this scope object will be added to the event
        // The global scope (calls to configureScope) will be ignored
        // Only do this if you know what you are doing, you loose a lot of useful info
        // If you just want to mutate what's in the scope use the callback, see: captureError
        SentrySDK.capture(exception: exception, scope: scope)
    }
    
    @IBAction func captureFatalError(_ sender: Any) {
        fatalError("This is a fatal error. Oh no 😬.")
    }
    
    @IBAction func captureTransaction(_ sender: Any) {
        let transaction = SentrySDK.startTransaction(name: "Some Transaction", operation: "Some Operation")
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

        dispatchQueue.async {
            for _ in 0...100_000 {
                i += Int.random(in: 0...10)
                i -= 1
                
                DispatchQueue.main.async {
                    self.anrFillingRunLoopButton.setTitle("Work in Progress \(i)", for: .normal)
                }
            }
            
            DispatchQueue.main.async {
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
}
