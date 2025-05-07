import Foundation
import Sentry
import UIKit

class AssertView: UIView {
    
    var span: Span?
    var autoHide = true
    
    private var assertLabel: UILabel!
    private var errorLabel: UILabel!
    
    var message: String? {
        get {
            return assertLabel.text
        }
        set {
            assertLabel.text = newValue
            setNeedsLayout()
        }
    }
    
    var errorMessage: String? {
        get {
            return errorLabel.text
        }
        set {
            errorLabel.text = newValue
            setNeedsLayout()
        }
    }
    
    convenience init() {
        self.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    private func initialize() {
        backgroundColor = UIColor(white: 0.3, alpha: 1)
        
        assertLabel = UILabel().forAutoLayout()
        assertLabel.textColor = UIColor(white: 1, alpha: 1)
        assertLabel.accessibilityIdentifier = "ASSERT_MESSAGE"
        addSubview(assertLabel)
        
        errorLabel = UILabel().forAutoLayout()
        errorLabel.textColor = UIColor(white: 1, alpha: 1)
        errorLabel.accessibilityIdentifier = "ASSERT_ERROR"
        errorLabel.numberOfLines = 0
        addSubview(errorLabel)
        
        let guide = self.safeAreaLayoutGuide
        
        let constraints = [
            assertLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            assertLabel.leftAnchor.constraint(equalTo: guide.leftAnchor, constant: 16),
            assertLabel.rightAnchor.constraint(equalTo: guide.rightAnchor, constant: -16),
            
            errorLabel.topAnchor.constraint(equalTo: assertLabel.bottomAnchor, constant: 16),
            errorLabel.leftAnchor.constraint(equalTo: guide.leftAnchor, constant: 16),
            errorLabel.rightAnchor.constraint(equalTo: guide.rightAnchor, constant: -16),
            errorLabel.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: 0)
        ]
        NSLayoutConstraint.activate(constraints)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        //If a tap occurs outside the view, it disappears
        let result = super.hitTest(point, with: event)
        if result == nil {
            close()
        }
        return result
    }
    
    private func close() {
        UIAssert.shared.reset()
        if autoHide {
            removeFromSuperview()
        }
    }
    
}
