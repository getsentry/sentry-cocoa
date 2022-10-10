import Foundation
import SentryObjc

public class SwiftDescriptor: NSObject, SentryDescriptorProtocol {
    public func getDescription(_ object: Any) -> String {
        if let cl = object as? AnyClass {
            return String(describing: cl)
        }
        
        return String(describing: object)
    }
}
