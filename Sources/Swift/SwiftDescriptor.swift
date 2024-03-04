import Foundation
import SentryPrivate

@objc
class SwiftDescriptor: NSObject {
    
    @objc
    static func getObjectClassName(_ object: AnyObject) -> String { 
        let d = SentryBaseIntegration()
        print(d)
        return String(describing: type(of: object))
    }
    
    @objc
    static func getSwiftErrorDescription(_ error: Error) -> String? {
        return String(describing: error)
    }
}
