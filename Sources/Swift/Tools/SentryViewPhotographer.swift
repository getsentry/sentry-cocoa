#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import CoreGraphics
import Foundation
import UIKit

@objcMembers
class SentryViewPhotographer: NSObject, SentryViewScreenshotProvider {
    
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
    
    func image(view: UIView, options: SentryRedactOptions, onComplete: @escaping ScreenshotCallback ) {
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        
        let redact = self.mask(view: view, options: options)
        
        DispatchQueue.global().async {
            let screenshot = UIGraphicsImageRenderer(size: view.bounds.size, format: .init(for: .init(displayScale: 1))).image { context in
                image.draw(at: .zero)
                
                for region in redact {
                    (region.color ?? self.averageColor(of: context.currentImage, at: region.rect)).setFill()
                    context.fill(region.rect)
                }
            }
            onComplete(screenshot)
        }
    }
    
    private func averageColor(of image: UIImage, at region: CGRect) -> UIColor {
        let colorImage = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: .init(for: .init(displayScale: 1))).image { context in
            guard let croppedImage = image.cgImage?.cropping(to: region) else {
                UIColor.black.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
                return
            }
            
            context.cgContext.draw(croppedImage, in: CGRect(x: 0, y: 0, width: 1, height: 1), byTiling: false)
        }
        
        guard
            let pixelData = colorImage.cgImage?.dataProvider?.data,
            let data = CFDataGetBytePtr(pixelData) else { return .black }
        
        let red = CGFloat(data[0]) / 255.0
        let green = CGFloat(data[1]) / 255.0
        let blue = CGFloat(data[2]) / 255.0
        let alpha = CGFloat(data[3]) / 255.0
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
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
