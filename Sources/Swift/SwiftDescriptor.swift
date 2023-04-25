import Foundation

@objc
public class SwiftDescriptor: NSObject {
    
    @objc
    public static func getObjectClassName(_ object: AnyObject) -> String {
        return String(describing: type(of: object))
    }
    
    @objc
    public static func getSwiftErrorDescription(_ error: Error) -> String? {
        let description = String(describing: error)
        
        // We can't reliably detect what is PII in a struct and what is not.
        // Furthermore, we can't detect which property contains the error enum.
        if description.contains(":") || description.contains(",") {
            return nil
        }
        
        // For error enums the description could contain PII in between (). Therefore,
        // we strip the data.
        let index = description.firstIndex(of: "(") ?? description.endIndex
        return String(description[..<index])
    }
    
}
