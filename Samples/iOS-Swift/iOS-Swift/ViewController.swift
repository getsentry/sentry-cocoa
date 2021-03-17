import Sentry
import UIKit

class ViewController: UIViewController {

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
    
    @IBAction func captureTransaction(_ sender: Any) {
        let transaction = SentrySDK.startTransaction(name: "Some Transaction", operation: "Some Operation")
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
}
