#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import ObjectiveC.NSObjCRuntime
import UIKit
#if os(iOS)
import WebKit
#endif

enum RedactRegionType {
    case clip
    case redact
}

struct RedactRegion {
    let size: CGSize
    let transform: CGAffineTransform
    let type: RedactRegionType
    let color: UIColor?
     
    init(size: CGSize, transform: CGAffineTransform, type: RedactRegionType, color: UIColor? = nil) {
        self.size = size
        self.transform = transform
        self.type = type
        self.color = color
    }
}

class UIRedactBuilder {
    
    //This is a list of UIView subclasses that will be ignored during redact process
    private var ignoreClassesIdentifiers: Set<ObjectIdentifier>
    //This is a list of UIView subclasses that need to be redacted from screenshot
    private var redactClassesIdentifiers: Set<ObjectIdentifier>
    
    init() {
        
        var redactClasses = [ UILabel.self, UITextView.self, UITextField.self ] +
        //this classes are used by SwiftUI to display images.
        ["_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView",
            "_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697122_UIShapeHitTestingView",
            "SwiftUI._UIGraphicsView", "SwiftUI.ImageLayer", "UIWebView"
        ].compactMap { NSClassFromString($0) }
        
#if os(iOS)
        redactClasses += [ WKWebView.self ]
        ignoreClassesIdentifiers = [ ObjectIdentifier(UISlider.self), ObjectIdentifier(UISwitch.self) ]
#else
        ignoreClassesIdentifiers = []
#endif
        redactClassesIdentifiers = Set(redactClasses.map({ ObjectIdentifier($0) }))
    }
    
    func containsIgnoreClass(_ ignoreClass: AnyClass) -> Bool {
        return  ignoreClassesIdentifiers.contains(ObjectIdentifier(ignoreClass))
    }
    
    func containsRedactClass(_ redactClass: AnyClass) -> Bool {
        var currentClass: AnyClass? = redactClass
        while currentClass != nil && currentClass != UIView.self {
            if let currentClass = currentClass, redactClassesIdentifiers.contains(ObjectIdentifier(currentClass)) {
                return true
            }
            currentClass = currentClass?.superclass()
        }
        return false
    }
    
    func addIgnoreClass(_ ignoreClass: AnyClass) {
        ignoreClassesIdentifiers.insert(ObjectIdentifier(ignoreClass))
    }
    
    func addRedactClass(_ redactClass: AnyClass) {
        redactClassesIdentifiers.insert(ObjectIdentifier(redactClass))
    }
    
    func addIgnoreClasses(_ ignoreClasses: [AnyClass]) {
        ignoreClasses.forEach(addIgnoreClass(_:))
    }
    
    func addRedactClasses(_ redactClasses: [AnyClass]) {
        redactClasses.forEach(addRedactClass(_:))
    }
    
    func redactRegionsFor(view: UIView, options: SentryRedactOptions?) -> [RedactRegion] {
        var redactingRegions = [RedactRegion]()
        
        self.mapRedactRegion(fromView: view,
                             to: view.layer.presentation() ?? view.layer,
                             redacting: &redactingRegions,
                             area: view.frame,
                             redactText: options?.redactAllText ?? true,
                             redactImage: options?.redactAllImages ?? true,
                             transform: CGAffineTransform.identity)
        
        return redactingRegions
    }
    
    private func shouldIgnore(view: UIView) -> Bool {
        return SentryRedactViewHelper.shouldIgnoreView(view) || containsIgnoreClass(type(of: view))
    }
    
    private func shouldRedact(view: UIView, redactText: Bool, redactImage: Bool) -> Bool {
        if SentryRedactViewHelper.shouldRedactView(view) {
            return true
        }
        if redactImage, let imageView = view as? UIImageView {
            return shouldRedact(imageView: imageView)
        }
        return redactText && containsRedactClass(type(of: view))
    }
    
    private func shouldRedact(imageView: UIImageView) -> Bool {
        // Checking the size is to avoid redact gradient background that
        // are usually small lines repeating
        guard let image = imageView.image, image.size.width > 10 && image.size.height > 10  else { return false }
        return image.imageAsset?.value(forKey: "_containingBundle") == nil
    }
    
    private func mapRedactRegion(fromView view: UIView, to: CALayer, redacting: inout [RedactRegion], area: CGRect, redactText: Bool, redactImage: Bool, transform: CGAffineTransform) {
        guard (redactImage || redactText) && !view.isHidden && view.alpha != 0 else { return }
        let layer = view.layer.presentation() ?? view.layer
        let size = layer.bounds.size
        let layerMiddle = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        
        var newTransform = transform.translatedBy(x: layer.position.x, y: layer.position.y)
        newTransform = view.transform.concatenating(newTransform)
        newTransform = newTransform.translatedBy(x: -layerMiddle.x, y: -layerMiddle.y)
        
        let ignore = shouldIgnore(view: view)
        let redact = shouldRedact(view: view, redactText: redactText, redactImage: redactImage)
        
        if !ignore && redact {
            redacting.append(RedactRegion(size: size, transform: newTransform, type: .redact, color: self.color(for: view)))
            return
        } else if hasBackground(view) {
            if layerOriginalFrame(layer: layer) == area {
                redacting.removeAll()
            } else {
                redacting.append(RedactRegion(size: size, transform: newTransform, type: .clip))
            }
        }
        
        if !ignore {
            for subview in view.subviews.sorted(by: { $0.layer.zPosition < $1.layer.zPosition }) {
                mapRedactRegion(fromView: subview, to: to, redacting: &redacting, area: area, redactText: redactText, redactImage: redactImage, transform: newTransform)
            }
        }
    }
    
    private func layerOriginalFrame(layer: CALayer) -> CGRect {
        let originalCenter = layer.position
        let originalBounds = layer.bounds
        
        return CGRect(
            x: originalCenter.x - originalBounds.width / 2,
            y: originalCenter.y - originalBounds.height / 2,
            width: originalBounds.width,
            height: originalBounds.height
        )
    }
    
    private func color(for view: UIView) -> UIColor? {
        return (view as? UILabel)?.textColor
    }
    
    private func hasBackground(_ view: UIView) -> Bool {
        //Anything with an alpha greater than 0.9 is opaque enough that it's impossible to see anything behind it.
        return view.backgroundColor != nil && view.alpha > 0.9 && (view.backgroundColor?.cgColor.alpha ?? 0) > 0.9
    }
}

@objcMembers
class SentryRedactViewHelper: NSObject {
    private static var associatedRedactObjectHandle: UInt8 = 0
    private static var associatedIgnoreObjectHandle: UInt8 = 0

    static func shouldRedactView(_ view: UIView) -> Bool {
        (objc_getAssociatedObject(view, &associatedRedactObjectHandle) as? NSNumber)?.boolValue ?? false
    }
    
    static func shouldIgnoreView(_ view: UIView) -> Bool {
        (objc_getAssociatedObject(view, &associatedIgnoreObjectHandle) as? NSNumber)?.boolValue ?? false
    }
    
    static func redactView(_ view: UIView) {
        objc_setAssociatedObject(view, &associatedRedactObjectHandle, true, .OBJC_ASSOCIATION_ASSIGN)
    }
    
    static func ignoreView(_ view: UIView) {
        objc_setAssociatedObject(view, &associatedIgnoreObjectHandle, true, .OBJC_ASSOCIATION_ASSIGN)
    }
}

#endif
#endif
