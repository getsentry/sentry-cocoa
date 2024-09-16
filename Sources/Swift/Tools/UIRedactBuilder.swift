#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import ObjectiveC.NSObjCRuntime
import UIKit
#if os(iOS)
import WebKit
#endif

enum RedactRegionType {
    /// Redacts the region.
    case redact
    
    /// Marks a region to not draw anything.
    /// This is used for opaque views.
    case clipOut
    
    /// Push a clip region to the drawing context.
    /// This is used for views that clip to its bounds.
    case clipBegin
    
    /// Pop the last Pushed region from the drawing context.
    /// Used after prossing every child of a view that clip to its bounds.
    case clipEnd
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
    
    ///This is a list of UIView subclasses that will be ignored during redact process
    private var ignoreClassesIdentifiers: Set<ObjectIdentifier>
    ///This is a list of UIView subclasses that need to be redacted from screenshot
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
    
    /**
     This function identifies and returns the regions within a given UIView that need to be redacted, based on the specified redaction options.
     
     - Parameter view: The root UIView for which redaction regions are to be calculated.
     - Parameter options: A `SentryRedactOptions` object specifying whether to redact all text (`redactAllText`) or all images (`redactAllImages`). If `options` is nil, defaults are used (redacting all text and images).
     
     - Returns: An array of `RedactRegion` objects representing areas of the view (and its subviews) that require redaction, based on the current visibility, opacity, and content (text or images).
     
     The method recursively traverses the view hierarchy, collecting redaction areas from the view and all its subviews. Each redaction area is calculated based on the view’s presentation layer, size, transformation matrix, and other attributes.
     
     The redaction process considers several key factors:
     1. **Text Redaction**: If `redactAllText` is set to true, regions containing text within the view or its subviews are marked for redaction.
     2. **Image Redaction**: If `redactAllImages` is set to true, image-containing regions are also marked for redaction.
     3. **Opaque View Handling**: If an opaque view covers the entire area, obfuscating views beneath it, those hidden views are excluded from processing, and we can remove them from the result.
     4. **Clip Area Creation**: If a smaller opaque view blocks another view, we create a clip area to avoid drawing a redact mask on top of a view that does not require redaction.
     
     This function returns the redaction regions in reverse order from what was found in the view hierarchy, allowing the processing of regions from top to bottom. This ensures that clip regions are applied first before drawing a redact mask on lower views.
     */
    func redactRegionsFor(view: UIView, options: SentryRedactOptions?) -> [RedactRegion] {
        var redactingRegions = [RedactRegion]()
        
        self.mapRedactRegion(fromView: view,
                             redacting: &redactingRegions,
                             rootFrame: view.frame,
                             redactOptions: options ?? SentryReplayOptions(),
                             transform: CGAffineTransform.identity)
        
        return redactingRegions.reversed()
    }
    
    private func shouldIgnore(view: UIView) -> Bool {
        return SentryRedactViewHelper.shouldIgnoreView(view) || containsIgnoreClass(type(of: view))
    }
    
    private func shouldRedact(view: UIView, redactOptions: SentryRedactOptions) -> Bool {
        if SentryRedactViewHelper.shouldRedactView(view) {
            return true
        }
        if redactOptions.redactAllImages, let imageView = view as? UIImageView {
            return shouldRedact(imageView: imageView)
        }
        return redactOptions.redactAllText && containsRedactClass(type(of: view))
    }
    
    private func shouldRedact(imageView: UIImageView) -> Bool {
        // Checking the size is to avoid redact gradient background that
        // are usually small lines repeating
        guard let image = imageView.image, image.size.width > 10 && image.size.height > 10  else { return false }
        return image.imageAsset?.value(forKey: "_containingBundle") == nil
    }
    
    private func mapRedactRegion(fromView view: UIView, redacting: inout [RedactRegion], rootFrame: CGRect, redactOptions: SentryRedactOptions, transform: CGAffineTransform) {
        guard (redactOptions.redactAllImages || redactOptions.redactAllText) && !view.isHidden && view.alpha != 0 else { return }
        
        let layer = view.layer.presentation() ?? view.layer
        
        let newTransform = concatenateTranform(transform, with: layer)
        
        let ignore = shouldIgnore(view: view)
        let redact = shouldRedact(view: view, redactOptions: redactOptions)
        
        if !ignore && redact {
            redacting.append(RedactRegion(size: layer.bounds.size, transform: newTransform, type: .redact, color: self.color(for: view)))
            return
        }
        
        if isOpaque(view) {
            let finalViewFrame = CGRect(origin: .zero, size: layer.bounds.size).applying(newTransform)
            if isAxisAligned(newTransform) && finalViewFrame == rootFrame {
                //Because the current view is covering everything we found so far we can clear `redacting` list
                redacting.removeAll()
            } else {
                redacting.append(RedactRegion(size: layer.bounds.size, transform: newTransform, type: .clipOut))
            }
        }
        
        guard !ignore else { return }
        
        if view.clipsToBounds {
            /// Because the order in which we process the redacted regions is reversed, we add the end of the clip region first.
            /// The beginning will be added after all the subviews have been mapped.
            redacting.append(RedactRegion(size: layer.bounds.size, transform: newTransform, type: .clipEnd))
        }
        for subview in view.subviews.sorted(by: { $0.layer.zPosition < $1.layer.zPosition }) {
            mapRedactRegion(fromView: subview, redacting: &redacting, rootFrame: rootFrame, redactOptions: redactOptions, transform: newTransform)
        }
        if view.clipsToBounds {
            redacting.append(RedactRegion(size: layer.bounds.size, transform: newTransform, type: .clipBegin))
        }
    }
    
    /**
     Apply the layer transformation and position to given transformation.
     */
    private func concatenateTranform(_ transform: CGAffineTransform, with layer: CALayer) -> CGAffineTransform {
        let size = layer.bounds.size
        let layerMiddle = CGPoint(x: size.width * layer.anchorPoint.x, y: size.height * layer.anchorPoint.y)
        
        var newTransform = transform.translatedBy(x: layer.position.x, y: layer.position.y)
        newTransform = CATransform3DGetAffineTransform(layer.transform).concatenating(newTransform)
        return newTransform.translatedBy(x: -layerMiddle.x, y: -layerMiddle.y)
    }
    
    /**
     Whether the transform does not contains rotation or skew
     */
    private func isAxisAligned(_ transform: CGAffineTransform) -> Bool {
        // Rotation exists if b or c are not zero
        return transform.b == 0 && transform.c == 0
    }

    private func color(for view: UIView) -> UIColor? {
        return (view as? UILabel)?.textColor
    }
    
    /**
     Indicates whether the view is opaque and will block other view behind it
     */
    private func isOpaque(_ view: UIView) -> Bool {
        return  view.alpha == 1 && view.backgroundColor != nil && (view.backgroundColor?.cgColor.alpha ?? 0) == 1
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
