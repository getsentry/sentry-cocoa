import Foundation
import Sentry
import UIKit

class UIAssert {
    
    static let shared = UIAssert()
    
    private let view = AssertView()

    private var isFailed = false
    
    private init() {
        view.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func assert(success: Bool, errorMessage: String?) {
        if isFailed {
            return
        }
        
        view.message = success ? "ASSERT: SUCCESS" : "ASSERT: FAIL"
        view.errorMessage = success ? "" : errorMessage
        isFailed = !success
        
        guard var targetViewController = UIApplication.shared.delegate?.window??.rootViewController else { return }
        
        while targetViewController.presentedViewController != nil {
            targetViewController = targetViewController.presentedViewController!
        }
        
        guard let targetView = targetViewController.view else { return }
        
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
    
    func reset() {
        isFailed = false
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
    
    static func hasViewControllerLifeCycle(_ span: Span, _ viewController: String) {
        guard let children = span.children() else {
            shared.assert(success: false, errorMessage: "\(viewController) span has no children")
            return
        }
        
        let loadViewSpan = children.first { $0.context.spanDescription == "loadView" }
        let viewDidLoadSpan = children.first { $0.context.spanDescription == "viewDidLoad" }
        let viewWillAppearSpan = children.first { $0.context.spanDescription == "viewWillAppear" }
        let viewDidAppearSpan = children.first { $0.context.spanDescription == "viewDidAppear" }
        
        notNil(loadViewSpan, "\(viewController) has no loadView span")
        notNil(viewDidLoadSpan, "\(viewController) has no viewDidLoad span")
        notNil(viewWillAppearSpan, "\(viewController) has no viewWillAppear span")
        notNil(viewDidAppearSpan, "\(viewController) has no viewDidAppear span")
        
    }
}
