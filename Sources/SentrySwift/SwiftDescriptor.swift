import Foundation
import UIKit

open class SwiftDescriptor {

    public init() {
    }
    
    public func hostViewControllerRootViewName(_ controller: UIViewController) -> String? {
        if let host = Mirror(reflecting: controller).descendant("host"),
           let hostView = Mirror(reflecting: host).children.first?.value,
           let rootView = Mirror(reflecting: hostView).children.first?.value,
           let storage = Mirror(reflecting: rootView).children.first?.value,
           let view = Mirror(reflecting: storage).children.first?.value {
            return String(describing: type(of: view))
        }
        
        return nil
    }
    
    func objectDescription(_ object: Any) -> String {
        return String(describing: object)
    }
}
