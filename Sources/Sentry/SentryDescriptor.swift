import Foundation

class SentryDescriptor: NSObject {
    
    @objc
    static func getDescription(_ object: AnyObject) -> String {
        return String(describing: object)
    }
}
