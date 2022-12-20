import Foundation
import Sentry
import UIKit

class UIAssert {
    
    static let shared = UIAssert()

    private let view = AssertView()

    private var isFailed = false
    
    var targetView: AssertView?
    
    private init() {
        view.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func assert(success: Bool, errorMessage: String?) {
        if isFailed {
            return
        }
        
        let assetView = targetView ?? view
                
        assetView.message = success ? "ASSERT: SUCCESS" : "ASSERT: FAIL"
        assetView.errorMessage = success ? "" : errorMessage
        isFailed = !success
        
        if targetView != nil {
            return
        }
        
        guard let window = UIApplication.shared.delegate?.window else { return }
        guard let target = window else { return }
        
        DispatchQueue.main.async {
            if self.view.superview != target {
                self.view.removeFromSuperview()
                
                target.addSubview(self.view)
                
                let constraints = [
                    self.view.leftAnchor.constraint(equalTo: target.leftAnchor, constant: 0),
                    self.view.rightAnchor.constraint(equalTo: target.rightAnchor, constant: 0),
                    self.view.bottomAnchor.constraint(equalTo: target.bottomAnchor, constant: 0)
                ]
                NSLayoutConstraint.activate(constraints)
            }
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
    
    static func fail(_ errorMessage: String? = nil) {
        shared.assert(success: false, errorMessage: errorMessage)
    }
    
    static func checkForViewControllerLifeCycle(_ transaction: Span, viewController: String, stepsToCheck: [String]? = nil, checkExcess: Bool = false) {
        guard var children = transaction.children() else {
            shared.assert(success: false, errorMessage: "\(viewController) span has no children")
            return
        }
        
        let steps = stepsToCheck ?? ["loadView", "viewDidLoad", "viewWillAppear", "viewDidAppear"]
        var missing = [String]()
        
        steps.forEach { spanDescription in
            let index = children.firstIndex { $0.spanDescription == spanDescription }
            
            if let spanIndex = index {
                children.remove(at: spanIndex)
            } else {
                missing.append(spanDescription)
            }
        }
        
        UIAssert.isEqual(missing.count, 0, "Following spans not found: \(missing.joined(separator: ", "))")
    }
}
