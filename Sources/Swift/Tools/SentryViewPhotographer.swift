#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

import CoreGraphics
import Foundation
import UIKit

@objcMembers
class SentryViewPhotographer: NSObject, SentryViewScreenshotProvider {
    
    static let shared = SentryViewPhotographer()
    
    private let redactBuilder = UIRedactBuilder()
        
    func image(view: UIView, options: SentryRedactOptions, onComplete: @escaping ScreenshotCallback ) {
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        
        let redact = redactBuilder.redactRegionsFor(view: view, options: options).reversed()
        let imageSize = view.bounds.size
        DispatchQueue.global().async {
            let screenshot = UIGraphicsImageRenderer(size: imageSize, format: .init(for: .init(displayScale: 1))).image { context in
                
                context.cgContext.addRect(CGRect(origin: CGPoint.zero, size: imageSize))
                context.cgContext.clip(using: .evenOdd)
                
                context.cgContext.interpolationQuality = .none
                image.draw(at: .zero)
                
                for region in redact {
                    context.cgContext.saveGState()
                    context.cgContext.concatenate(region.transform)
                    
                    let rect = CGRect(origin: CGPoint.zero, size: region.size)
                    switch region.type {
                    case .redact:
                        (region.color ?? UIImageHelper.averageColor(of: context.currentImage, at: rect)).setFill()
                        context.fill(rect)
                        context.cgContext.restoreGState()
                    case .clip:
                        context.cgContext.addRect(context.cgContext.boundingBoxOfClipPath)
                        context.cgContext.addRect(rect)
                        context.cgContext.restoreGState()
                        context.cgContext.clip(using: .evenOdd)
                    }
                    
                }
            }
            onComplete(screenshot)
        }
    }
    
    @objc(addIgnoreClasses:)
    func addIgnoreClasses(classes: [AnyClass]) {
        redactBuilder.addIgnoreClasses(classes)
    }

    @objc(addRedactClasses:)
    func addRedactClasses(classes: [AnyClass]) {
        redactBuilder.addRedactClasses(classes)
    }
    
#if TEST || TESTCI
    func getRedactBuild() -> UIRedactBuilder {
        redactBuilder
    }
#endif
    
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
