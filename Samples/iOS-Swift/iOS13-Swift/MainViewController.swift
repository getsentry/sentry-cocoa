import Sentry
import UIKit

class MainViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }
    
    @IBAction func captureMessage(_ sender: UIButton) {
        highlightButton(sender)
        let eventId = SentrySDK.capture(message: "Yeah captured a message")
        // Returns eventId in case of successfull processed event
        // otherwise nil
        print("\(String(describing: eventId))")
    }
    
    @IBAction func captureError(_ sender: UIButton) {
        highlightButton(sender)
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
    
    @IBAction func crash(_ sender: UIButton) {
        SentrySDK.crash()
    }
    
}
