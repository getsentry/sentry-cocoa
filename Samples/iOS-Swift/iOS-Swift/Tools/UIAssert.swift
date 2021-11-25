import Foundation
import UIKit

class UIAssert {
    
    static let shared = UIAssert()
    
    private let view = AssertView()

    private init() {
        view.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func assert(success: Bool, errorMessage: String?) {
        view.message = success ? "ASSERT: SUCCESS" : "ASSERT: FAIL"
        view.errorMessage = success ? "" : errorMessage
        
        guard let targetView = UIApplication.shared.delegate?.window??.rootViewController?.view else { return }
        
        if view.superview != targetView {
            view.removeFromSuperview()
            
            targetView.addSubview(view)
            
            let constraints = [
                view.leftAnchor.constraint(equalTo: targetView.leftAnchor, constant: 0),
                view.rightAnchor.constraint(equalTo: targetView.rightAnchor, constant: 0),
                view.bottomAnchor.constraint(equalTo: targetView.bottomAnchor, constant: 0)
            ]
            NSLayoutConstraint.activate(constraints)
        }
    }
    
    static func isTrue(_ value: Bool, _ errorMessage: String? = nil) {
        shared.assert(success: value, errorMessage: errorMessage)
    }
    
    static func isFalse(_ value: Bool, _ errorMessage: String? = nil) {
        shared.assert(success: !value, errorMessage: errorMessage)
    }
    
    static func isEqual<T>(_ first: T, _ second: T, _ errorMessage: String? = nil)  where T: Equatable {
        shared.assert(success: first == second, errorMessage: errorMessage)
    }
    
    static func notNil(_ value: Any?, _ errorMessage: String? = nil) {
        shared.assert(success: value != nil, errorMessage: errorMessage)
    }
    
    static func isNil(_ value: Any?, _ errorMessage: String? = nil) {
        shared.assert(success: value == nil, errorMessage: errorMessage)
    }
    
}
