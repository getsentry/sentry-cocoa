import UIKit

class SentryTestLogOutput: NSObject, SentryLogOutputProtocol {
    static var df: Formatter = {
        if #available(iOS 10.0, *) {
            return ISO8601DateFormatter()
        } else {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            df.locale = Locale(identifier: "en_US_POSIX")
            df.calendar = Calendar(identifier: .gregorian)
            return df
        }
    }()

    func log(_ message: String) {
        NSLog("%@", message)
    }
}
