#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import ObjectiveC.NSObjCRuntime
import UIKit
#if os(iOS)
import PDFKit
import WebKit
#endif

final class SentryUIRedactBuilder {
    // MARK: - Constants

    /// Class identifier for ``CameraUI.ChromeSwiftUIView``, if it exists.
    ///
    /// This object identifier is used to identify views of this class type during the redaction process.
    /// This workaround is specifically for Xcode 16 building for iOS 26 where accessing CameraUI.ModeLoupeLayer
    /// causes a crash due to unimplemented init(layer:) initializer.
    private static let cameraSwiftUIViewClassId = "CameraUI.ChromeSwiftUIView"

    ///This is a wrapper which marks it's direct children to be ignored
    private var ignoreContainerClassIdentifier: ObjectIdentifier?
    
    ///This is a wrapper which marks it's direct children to be redacted
    private var redactContainerClassIdentifier: ObjectIdentifier?

    ///This is a list of UIView subclasses that will be ignored during redact process
    private var ignoreClassesIdentifiers: Set<ObjectIdentifier>

    /// This is a list of UIView subclasses that need to be redacted from screenshot
    ///
    /// This set is configured as `private(set)` to allow modification only from within this class,
    /// while still allowing read access from tests.
    private(set) var redactClassesIdentifiers: Set<ObjectIdentifier>

    /**
     Initializes a new instance of the redaction process with the specified options.

     This initializer configures which `UIView` subclasses should be redacted from screenshots and which should be ignored during the redaction process.

     - parameter options: A `SentryRedactOptions` object that specifies the configuration for the redaction process.
     
     - If `options.maskAllText` is `true`, common text-related views such as `UILabel`, `UITextView`, and `UITextField` are redacted.
     - If `options.maskAllImages` is `true`, common image-related views such as `UIImageView` and various internal `SwiftUI` image views are redacted.
     - The `options.unmaskViewTypes` allows specifying custom view types to be ignored during the redaction process.
     - The `options.maskViewTypes` allows specifying additional custom view types to be redacted.

     - note: On iOS, views such as `WKWebView` and `UIWebView` are automatically redacted, and controls like `UISlider` and `UISwitch` are ignored.
     */
    init(options: SentryRedactOptions) {
        var redactClasses = [AnyClass]()
        
        if options.maskAllText {
            redactClasses += [ UILabel.self, UITextView.self, UITextField.self ]
            // These classes are used by React Native to display text.
            // We are including them here to avoid leaking text from RN apps with manually initialized sentry-cocoa.
            redactClasses += ["RCTTextView", "RCTParagraphComponentView"].compactMap(NSClassFromString(_:))
        }
        
        if options.maskAllImages {
            //this classes are used by SwiftUI to display images.
            redactClasses += ["_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView",
             "_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697122_UIShapeHitTestingView",
             "SwiftUI._UIGraphicsView", "SwiftUI.ImageLayer"
            ].compactMap(NSClassFromString(_:))

            // These classes are used by React Native to display images/vectors.
            // We are including them here to avoid leaking images from RN apps with manually initialized sentry-cocoa.
            redactClasses += ["RCTImageView"].compactMap(NSClassFromString(_:))
            
            redactClasses.append(UIImageView.self)
        }
        
#if os(iOS)
        redactClasses += [ PDFView.self, WKWebView.self ]

        redactClasses += [
            // If we try to use 'UIWebView.self' it will not compile for macCatalyst, but the class does exists.
            "UIWebView",
            // Used by:
            // - https://developer.apple.com/documentation/SafariServices/SFSafariViewController
            // - https://developer.apple.com/documentation/AuthenticationServices/ASWebAuthenticationSession
            "SFSafariView",
            // Used by:
            // - https://developer.apple.com/documentation/avkit/avplayerviewcontroller
            "AVPlayerView"
        ].compactMap(NSClassFromString(_:))

        ignoreClassesIdentifiers = [ ObjectIdentifier(UISlider.self), ObjectIdentifier(UISwitch.self) ]
#else
        ignoreClassesIdentifiers = []
#endif
        
        redactClassesIdentifiers = Set(redactClasses.map({ ObjectIdentifier($0) }))
        
        for type in options.unmaskedViewClasses {
            self.ignoreClassesIdentifiers.insert(ObjectIdentifier(type))
        }
        
        for type in options.maskedViewClasses {
            self.redactClassesIdentifiers.insert(ObjectIdentifier(type))
        }
    }
    
    func containsIgnoreClass(_ ignoreClass: AnyClass) -> Bool {
        return ignoreClassesIdentifiers.contains(ObjectIdentifier(ignoreClass))
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

    func setIgnoreContainerClass(_ containerClass: AnyClass) {
        ignoreContainerClassIdentifier = ObjectIdentifier(containerClass)
    }

    func setRedactContainerClass(_ containerClass: AnyClass) {
        let id = ObjectIdentifier(containerClass)
        redactContainerClassIdentifier = id
        redactClassesIdentifiers.insert(id)
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    func isIgnoreContainerClassTestOnly(_ containerClass: AnyClass) -> Bool {
        return isIgnoreContainerClass(containerClass)
    }

    func isRedactContainerClassTestOnly(_ containerClass: AnyClass) -> Bool {
        return isRedactContainerClass(containerClass)
    }
#endif

    /**
     This function identifies and returns the regions within a given UIView that need to be redacted, based on the specified redaction options.
     
     - Parameter view: The root UIView for which redaction regions are to be calculated.
     - Parameter options: A `SentryRedactOptions` object specifying whether to redact all text (`maskAllText`) or all images (`maskAllImages`). If `options` is nil, defaults are used (redacting all text and images).
     
     - Returns: An array of `RedactRegion` objects representing areas of the view (and its subviews) that require redaction, based on the current visibility, opacity, and content (text or images).
     
     The method recursively traverses the view hierarchy, collecting redaction areas from the view and all its subviews. Each redaction area is calculated based on the view’s presentation layer, size, transformation matrix, and other attributes.
     
     The redaction process considers several key factors:
     1. **Text Redaction**: If `maskAllText` is set to true, regions containing text within the view or its subviews are marked for redaction.
     2. **Image Redaction**: If `maskAllImages` is set to true, image-containing regions are also marked for redaction.
     3. **Opaque View Handling**: If an opaque view covers the entire area, obfuscating views beneath it, those hidden views are excluded from processing, and we can remove them from the result.
     4. **Clip Area Creation**: If a smaller opaque view blocks another view, we create a clip area to avoid drawing a redact mask on top of a view that does not require redaction.
     
     This function returns the redaction regions in reverse order from what was found in the view hierarchy, allowing the processing of regions from top to bottom. This ensures that clip regions are applied first before drawing a redact mask on lower views.
     */
    func redactRegionsFor(view: UIView) -> [SentryRedactRegion] {
        var redactingRegions = [SentryRedactRegion]()
        
        self.mapRedactRegion(fromLayer: view.layer.presentation() ?? view.layer,
                             relativeTo: nil,
                             redacting: &redactingRegions,
                             rootFrame: view.frame,
                             transform: .identity)

        var swiftUIRedact = [SentryRedactRegion]()
        var otherRegions = [SentryRedactRegion]()
        
        for region in redactingRegions {
            if region.type == .redactSwiftUI {
                swiftUIRedact.append(region)
            } else {
                otherRegions.append(region)
            }
        }
        
        //The swiftUI type needs to appear first in the list so it always get masked
        return (otherRegions + swiftUIRedact).reversed()
    }
    
    private func shouldIgnore(view: UIView) -> Bool {
        return SentryRedactViewHelper.shouldUnmask(view) || containsIgnoreClass(type(of: view)) || shouldIgnoreParentContainer(view)
    }

    private func shouldIgnoreParentContainer(_ view: UIView) -> Bool {
        guard !isRedactContainerClass(type(of: view)), let parent = view.superview else { return false }
        return isIgnoreContainerClass(type(of: parent))
    }

    private func isIgnoreContainerClass(_ containerClass: AnyClass) -> Bool {
        guard ignoreContainerClassIdentifier != nil  else { return false }
        return ObjectIdentifier(containerClass) == ignoreContainerClassIdentifier
    }

    private func isRedactContainerClass(_ containerClass: AnyClass) -> Bool {
        guard redactContainerClassIdentifier != nil  else { return false }
        return ObjectIdentifier(containerClass) == redactContainerClassIdentifier
    }

    private func shouldRedact(view: UIView) -> Bool {
        if SentryRedactViewHelper.shouldMaskView(view) {
            return true
        }
        if let imageView = view as? UIImageView, containsRedactClass(UIImageView.self) {
            return shouldRedact(imageView: imageView)
        }
        return containsRedactClass(type(of: view))
    }
    
    private func shouldRedact(imageView: UIImageView) -> Bool {
        // Checking the size is to avoid redact gradient background that
        // are usually small lines repeating
        guard let image = imageView.image, image.size.width > 10 && image.size.height > 10  else { return false }
        return image.imageAsset?.value(forKey: "_containingBundle") == nil
    }

    // swiftlint:disable:next function_body_length
    private func mapRedactRegion(fromLayer layer: CALayer, relativeTo parentLayer: CALayer?, redacting: inout [SentryRedactRegion], rootFrame: CGRect, transform: CGAffineTransform, forceRedact: Bool = false) {
        guard !redactClassesIdentifiers.isEmpty && !layer.isHidden && layer.opacity != 0, let view = layer.delegate as? UIView else {
            return
        }
        let newTransform = concatenateTranform(transform, from: layer, withParent: parentLayer)
        
        // Check if the subtree should be ignored to avoid crashes with some special views.
        // If a subtree is ignored, it will be fully redacted and we return early to prevent duplicates.
        if isViewSubtreeIgnored(view) {
            redacting.append(SentryRedactRegion(
                size: layer.bounds.size,
                transform: newTransform,
                type: .redact,
                color: self.color(for: view),
                name: view.debugDescription
            ))
            return
        }
        
        let ignore = !forceRedact && shouldIgnore(view: view)
        let swiftUI = SentryRedactViewHelper.shouldRedactSwiftUI(view)
        let redact = forceRedact || shouldRedact(view: view) || swiftUI
        var enforceRedact = forceRedact
        
        if !ignore && redact {
            redacting.append(SentryRedactRegion(
                size: layer.bounds.size,
                transform: newTransform,
                type: swiftUI ? .redactSwiftUI : .redact,
                color: self.color(for: view),
                name: view.debugDescription
            ))

            guard !view.clipsToBounds else {
                return
            }
            enforceRedact = true
        } else if isOpaque(view) {
            let finalViewFrame = CGRect(origin: .zero, size: layer.bounds.size).applying(newTransform)
            if isAxisAligned(newTransform) && finalViewFrame == rootFrame {
                //Because the current view is covering everything we found so far we can clear `redacting` list
                redacting.removeAll()
            } else {
                redacting.append(SentryRedactRegion(
                    size: layer.bounds.size,
                    transform: newTransform,
                    type: .clipOut,
                    name: view.debugDescription
                ))
            }
        }

        // Traverse the sublayers to redact them if necessary
        guard let subLayers = layer.sublayers, subLayers.count > 0 else {
            return
        }
        let clipToBounds = view.clipsToBounds
        if clipToBounds {
            /// Because the order in which we process the redacted regions is reversed, we add the end of the clip region first.
            /// The beginning will be added after all the subviews have been mapped.
            redacting.append(SentryRedactRegion(
                size: layer.bounds.size,
                transform: newTransform,
                type: .clipEnd,
                name: view.debugDescription
            ))
        }
        for subLayer in subLayers.sorted(by: { $0.zPosition < $1.zPosition }) {
            mapRedactRegion(fromLayer: subLayer, relativeTo: layer, redacting: &redacting, rootFrame: rootFrame, transform: newTransform, forceRedact: enforceRedact)
        }
        if clipToBounds {
            redacting.append(SentryRedactRegion(
                size: layer.bounds.size,
                transform: newTransform,
                type: .clipBegin,
                name: view.debugDescription
            ))
        }
    }

    private func isViewSubtreeIgnored(_ view: UIView) -> Bool {
        // We intentionally avoid using `NSClassFromString` or directly referencing class objects here,
        // because both approaches can trigger the Objective-C `+initialize` method on the class.
        // This has side effects and can cause crashes, especially when performed off the main thread
        // or with UIKit classes that expect to be initialized on the main thread.
        //
        // Instead, we use the string description of the type (i.e., `type(of: view).description()`)
        // for comparison. This is a safer, more "Swifty" approach that avoids the pitfalls of
        // class initialization side effects.
        //
        // We have previously encountered related issues:
        // - In EmergeTools' snapshotting code where using `NSClassFromString` led to crashes [1]
        // - In Sentry's own SubClassFinder where storing or accessing class objects on a background thread caused crashes due to `+initialize` being called on UIKit classes [2]
        //
        // [1] https://github.com/EmergeTools/SnapshotPreviews/blob/main/Sources/SnapshotPreviewsCore/View%2BSnapshot.swift#L248
        // [2] https://github.com/getsentry/sentry-cocoa/blob/00d97404946a37e983eabb21cc64bd3d5d2cb474/Sources/Sentry/SentrySubClassFinder.m#L58-L84   
        let viewTypeId = type(of: view).description()
        
        if #available(iOS 26.0, *), viewTypeId == Self.cameraSwiftUIViewClassId {
            // CameraUI.ChromeSwiftUIView is a special case because it contains layers which can not be iterated due to this error:
            //
            // Fatal error: Use of unimplemented initializer 'init(layer:)' for class 'CameraUI.ModeLoupeLayer'
            //
            // This crash only occurs when building with Xcode 16 for iOS 26, so we add a runtime check
            return true
        }
        return false
    }

    /**
     Gets a transform that represents the layer global position.
     */
    private func concatenateTranform(_ transform: CGAffineTransform, from layer: CALayer, withParent parentLayer: CALayer?) -> CGAffineTransform {
        let size = layer.bounds.size
        let anchorPoint = CGPoint(x: size.width * layer.anchorPoint.x, y: size.height * layer.anchorPoint.y)
        let position = parentLayer?.convert(layer.position, to: nil) ?? layer.position
        
        var newTransform = transform
        newTransform.tx = position.x
        newTransform.ty = position.y
        newTransform = CATransform3DGetAffineTransform(layer.transform).concatenating(newTransform)
        return newTransform.translatedBy(x: -anchorPoint.x, y: -anchorPoint.y)
    }
    
    /**
     Whether the transform does not contains rotation or skew
     */
    private func isAxisAligned(_ transform: CGAffineTransform) -> Bool {
        // Rotation exists if b or c are not zero
        return transform.b == 0 && transform.c == 0
    }

    private func color(for view: UIView) -> UIColor? {
        return (view as? UILabel)?.textColor.withAlphaComponent(1)
    }
    
    /**
     Indicates whether the view is opaque and will block other view behind it
     */
    private func isOpaque(_ view: UIView) -> Bool {
        let layer = view.layer.presentation() ?? view.layer
        return SentryRedactViewHelper.shouldClipOut(view) || (layer.opacity == 1 && view.backgroundColor != nil && (view.backgroundColor?.cgColor.alpha ?? 0) == 1)
    }
}

#endif
#endif
