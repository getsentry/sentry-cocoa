import Foundation

#if canImport(UIKit)
import CoreGraphics
import UIKit

@objcMembers
class SentryViewPhotographer: NSObject {
    
    private var ignoreClasses: [AnyClass] = []
    private var redactClasses: [AnyClass] = []
    
    static let shared = SentryViewPhotographer()
    
    override init() {
#if os(iOS)
        ignoreClasses = [  UISlider.self, UISwitch.self ]
#endif
        redactClasses = [ UILabel.self, UITextView.self, UITextField.self ] + [
            "_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView",
            "_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697122_UIShapeHitTestingView",
            "SwiftUI._UIGraphicsView", "SwiftUI.ImageLayer"
        ].compactMap { NSClassFromString($0) }
    }
    
    func image(view: UIView) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, true, 0)
        if let currentContext = UIGraphicsGetCurrentContext() {
            view.layer.render(in: currentContext)
            self.mask(view: view, context: currentContext)
            if let screenshot = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                return screenshot
            }
        }
        UIGraphicsEndImageContext()
        return nil
    }
    
    private func mask(view: UIView, context: CGContext) {
        UIColor.black.setFill()
        let maskPath = self.buildPath(view: view, path: CGMutablePath(), area: view.frame)
        context.addPath(maskPath)
        context.fillPath()
    }
    
    private func shouldIgnore(view: UIView) -> Bool {
        ignoreClasses.contains { view.isKind(of: $0) }
    }
    
    private func shouldRedact(view: UIView) -> Bool {
        if let imageView = view as? UIImageView {
            return shouldRedact(imageView: imageView)
        }
        
        return redactClasses.contains { view.isKind(of: $0) }
    }
    
    private func shouldRedact(imageView: UIImageView) -> Bool {
        // Checking the size is to avoid redact gradient backgroud that
        // are usually small lines repeating
        guard let image = imageView.image, image.size.width > 10 && image.size.height > 10  else { return false }
        return image.imageAsset?.value(forKey: "_containingBundle") != nil
    }
    
    private func buildPath(view: UIView, path: CGMutablePath, area: CGRect) -> CGMutablePath {
        let rectInWindow = view.convert(view.bounds, to: nil)

        if !area.intersects(rectInWindow) || view.isHidden || view.alpha == 0 {
            return path
        }
        
        var result = path

        let ignore = shouldIgnore(view: view)
        
        if !ignore && shouldRedact(view: view) {
            result.addRect(rectInWindow)
            return result
        } else if isOpaqueOrHasBackground(view) {
            let newPath = excludeRect(rectInWindow, fromPath: result)
            result = newPath
        }

        if !ignore {
            for subview in view.subviews {
                result = buildPath(view: subview, path: path, area: area)
            }
        }

        return result
    }
    
    private func excludeRect(_ rectangle: CGRect, fromPath path: CGMutablePath) -> CGMutablePath {
        if #available(iOS 16.0, tvOS 16.0, *) {
            let exclude = CGPath(rect: rectangle, transform: nil)
            let newPath = path.subtracting(exclude, using: .evenOdd)
            return newPath.mutableCopy() ?? path
        }
        return path
    }
    
    private func isOpaqueOrHasBackground(_ view: UIView) -> Bool {
        return view.isOpaque || (view.backgroundColor != nil && (view.backgroundColor?.cgColor.alpha ?? 0) > 0.9)
    }
}

#endif // canImport(UIKit)
