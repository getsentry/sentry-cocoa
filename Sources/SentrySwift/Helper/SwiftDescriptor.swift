import Foundation
import SentryObjc
import SwiftUI
import UIKit

public class SwiftDescriptor: NSObject, SentryDescriptorProtocol {
    
    //Delete this if we dont use it by the end of the PR
    public func hostViewControllerRootViewName(_ controller: UIViewController) -> String? {
        print("\(String(describing: type(of: controller)))")
        if let host = Mirror(reflecting: controller).descendant("host"),
           let hostView = Mirror(reflecting: host).children.first?.value,
           let rootView = Mirror(reflecting: hostView).children.first?.value,
           let storage = Mirror(reflecting: rootView).children.first?.value,
           let view = Mirror(reflecting: storage).children.first?.value {
            
           let t = type(of: view)
           return String(describing: t)
        }
        
        return nil
    }
        
    public func getDescription(_ object: Any) -> String {
        return String(describing: object)
    }
}
