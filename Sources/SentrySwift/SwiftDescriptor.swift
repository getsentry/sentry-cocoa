import Foundation

@objc
public class SwiftDescriptor: NSObject {
 
    @objc
    public static func getDescription(_ object: AnyObject) -> String {
        return String(describing: type(of: object))
    }
    
}
