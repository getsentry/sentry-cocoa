import Foundation

@objc
public class SwiftDescriptor: NSObject {
 
    @objc
    public static func getDescription(_ object: AnyObject) -> String {
        if let objClass = object as? AnyClass {
            return String(describing: objClass)
        }
        return String(describing: object)
    }
    
}
