import UIKit

class SentryTestLogOutput: NSObject, SentryLogOutputProtocol {
    func log(_ message: String) {
        NSLog("%@", message)
    }
}
