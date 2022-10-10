import Foundation
import SentryObjc

public class SwiftDescriptor: NSObject, SentryDescriptorProtocol {
    public func getDescription(_ object: Any) -> String {
        return String(describing: object)
    }
}
