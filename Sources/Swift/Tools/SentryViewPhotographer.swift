#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import CoreGraphics
import Foundation
import UIKit

@available(iOS, introduced: 16.0)
@available(tvOS, introduced: 16.0)
@objcMembers
class SentryViewPhotographer: NSObject {
    
    private struct RedactRegion {
        let rect: CGRect
        let color: UIColor?
        
        func splitBySubtracting(region: CGRect) -> [RedactRegion] {
            guard rect.intersects(region) else { return [self] }
            guard !region.contains(rect) else { return [] }
            
            let intersectionRect = rect.intersection(region)
            var resultRegions: [CGRect] = []
            
            // Calculate the top region.
            resultRegions.append(CGRect(x: rect.minX,
                                        y: rect.minY,
                                        width: rect.width,
                                        height: intersectionRect.minY - rect.minY))
            
            // Calculate the bottom region.
            resultRegions.append(CGRect(x: rect.minX,
                                        y: intersectionRect.maxY,
                                        width: rect.width,
                                        height: rect.maxY - intersectionRect.maxY))
            
            // Calculate the left region.
            resultRegions.append(CGRect(x: rect.minX,
                                        y: max(rect.minY, intersectionRect.minY),
                                        width: intersectionRect.minX - rect.minX,
                                        height: min(intersectionRect.maxY, rect.maxY) - max(rect.minY, intersectionRect.minY)))
            
            // Calculate the right region.
            resultRegions.append(CGRect(x: intersectionRect.maxX,
                                        y: max(rect.minY, intersectionRect.minY),
                                        width: rect.maxX - intersectionRect.maxX,
                                        height: min(intersectionRect.maxY, rect.maxY) - max(rect.minY, intersectionRect.minY)))
            
            return resultRegions.filter { !$0.isEmpty }.map { RedactRegion(rect: $0, color: color) }
        }
    }
    
    //This is a list of UIView subclasses that will be ignored during redact process
    private var ignoreClasses: [AnyClass] = []
    //This is a list of UIView subclasses that need to be redacted from screenshot
    private var redactClasses: [AnyClass] = []
    
    static let shared = SentryViewPhotographer()
    
    override init() {
#if os(iOS)
        ignoreClasses = [ UISlider.self, UISwitch.self ]
#endif // os(iOS)
        redactClasses = [ UILabel.self, UITextView.self, UITextField.self ] + [
            "_TtCOCV7SwiftUI11DisplayList11ViewUpdater8Platform13CGDrawingView",
            "_TtC7SwiftUIP33_A34643117F00277B93DEBAB70EC0697122_UIShapeHitTestingView",
            "SwiftUI._UIGraphicsView", "SwiftUI.ImageLayer"
        ].compactMap { NSClassFromString($0) }
    }
    
    @objc(imageWithView:options:)
    func image(view: UIView, options: SentryRedactOptions) -> UIImage? {
        
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        
      //  let mask = self.mask(view: view, options: options)
        let maskSize = view.bounds.size.applying(CGAffineTransformMakeScale(0.005, 0.005))
        
        let maskColor = UIGraphicsImageRenderer(size: maskSize).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: maskSize.width, height: maskSize.height))
        }
        
        let screenshot = UIGraphicsImageRenderer(size: view.bounds.size).image { context in
            image.draw(at: .zero)
            
            context.cgContext.setFillColor(UIColor.red.cgColor)
            
            context.cgContext.clip()
            maskColor.draw(in: view.bounds)
            context.cgContext.restoreGState()
        }
        
        return screenshot
    }
    
    private func mask(view: UIView, options: SentryRedactOptions?) -> [RedactRegion] {
        var redactingRegions = [RedactRegion]()
        
        self.mapRedactRegion(fromView: view, 
                             redacting: &redactingRegions,
                             area: view.frame,
                             redactText: options?.redactAllText ?? true,
                             redactImage: options?.redactAllImages ?? true)
        
        return redactingRegions
    }
    
    private func shouldIgnore(view: UIView) -> Bool {
        ignoreClasses.contains { view.isKind(of: $0) }
    }
    
    private func shouldRedact(view: UIView, redactText: Bool, redactImage: Bool) -> Bool {
        if redactImage, let imageView = view as? UIImageView {
            return shouldRedact(imageView: imageView)
        }
        return redactText && redactClasses.contains { view.isKind(of: $0) }
    }
    
    private func shouldRedact(imageView: UIImageView) -> Bool {
        // Checking the size is to avoid redact gradient backgroud that
        // are usually small lines repeating
        guard let image = imageView.image, image.size.width > 10 && image.size.height > 10  else { return false }
        return image.imageAsset?.value(forKey: "_containingBundle") == nil
    }
    
    private func mapRedactRegion(fromView view: UIView, redacting: inout [RedactRegion], area: CGRect, redactText: Bool, redactImage: Bool) {
        let rectInWindow = view.convert(view.bounds, to: nil)
        guard redactImage || redactText || area.intersects(rectInWindow) || !view.isHidden || view.alpha != 0 else { return }
        
        let ignore = shouldIgnore(view: view)
        let redact = shouldRedact(view: view, redactText: redactText, redactImage: redactImage)
        
        if !ignore && redact {
            redacting.append(RedactRegion(rect: rectInWindow, color: self.color(for: view)))
            return
        } else if isOpaqueOrHasBackground(view) {
            if rectInWindow == area {
                redacting.removeAll()
            } else {
                redacting = redacting.flatMap { $0.splitBySubtracting(region: rectInWindow) }
            }
        }
        
        if !ignore {
            for subview in view.subviews {
                mapRedactRegion(fromView: subview, redacting: &redacting, area: area, redactText: redactText, redactImage: redactImage)
            }
        }
    }
    
    private func color(for view: UIView) -> UIColor? {
        return (view as? UILabel)?.textColor
    }
    
    private func isOpaqueOrHasBackground(_ view: UIView) -> Bool {
        return view.isOpaque || (view.backgroundColor != nil && (view.backgroundColor?.cgColor.alpha ?? 0) > 0.9)
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
