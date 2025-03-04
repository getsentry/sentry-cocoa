import UIKit

@objc protocol SentryViewRenderer {
    func render(view: UIView) -> UIImage
}
