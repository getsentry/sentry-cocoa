#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import CoreGraphics
import Foundation
import UIKit

protocol ViewRenderer {
    func render(view: UIView) -> UIImage
}

class DefaultViewRenderer: ViewRenderer {
    func render(view: UIView) -> UIImage {
        let image = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        }
        return image
    }
}

@objcMembers
class SentryViewPhotographer: NSObject, SentryViewScreenshotProvider {
    private let redactBuilder: UIRedactBuilder
    private let dispatchQueue = SentryDispatchQueueWrapper()

    var renderer: ViewRenderer
        
    init(renderer: ViewRenderer, redactOptions: SentryRedactOptions) {
        self.renderer = renderer
        redactBuilder = UIRedactBuilder(options: redactOptions)
        super.init()
    }
    
    init(redactOptions: SentryRedactOptions) {
        self.renderer = DefaultViewRenderer()
        self.redactBuilder = UIRedactBuilder(options: redactOptions)
    }
    
    func image(view: UIView, onComplete: @escaping ScreenshotCallback) {
        let redact = redactBuilder.redactRegionsFor(view: view)
        let image = renderer.render(view: view)
        let viewSize = view.bounds.size
        
        dispatchQueue.dispatchAsync {
            let screenshot = self.maskScreenshot(screenshot: image, size: viewSize, masking: redact)
            onComplete(screenshot)
        }
    }
    
    func image(view: UIView) -> UIImage {
        let redact = redactBuilder.redactRegionsFor(view: view)
        let image = renderer.render(view: view)
        let viewSize = view.bounds.size
        
        return self.maskScreenshot(screenshot: image, size: viewSize, masking: redact)
    }
    
    private func maskScreenshot(screenshot image: UIImage, size: CGSize, masking: [RedactRegion]) -> UIImage {
        
        let screenshot = UIGraphicsImageRenderer(size: size, format: .init(for: .init(displayScale: 1))).image { context in
            
            let clipOutPath = CGMutablePath(rect: CGRect(origin: .zero, size: size), transform: nil)
            var clipPaths = [CGPath]()
            
            let imageRect = CGRect(origin: .zero, size: size)
            context.cgContext.addRect(CGRect(origin: CGPoint.zero, size: size))
            context.cgContext.clip(using: .evenOdd)
            
            context.cgContext.interpolationQuality = .none
            image.draw(at: .zero)
            
            var latestRegion: RedactRegion?
            for region in masking {
                let rect = CGRect(origin: CGPoint.zero, size: region.size)
                var transform = region.transform
                let path = CGPath(rect: rect, transform: &transform)
                
                defer { latestRegion = region }
                
                switch region.type {
                case .redact, .redactSwiftUI:
                    // This early return is to avoid masking the same exact area in row,
                    // something that is very common in SwiftUI and can impact performance.
                    guard latestRegion?.canReplace(as: region) != true && imageRect.intersects(path.boundingBoxOfPath) else { continue }
                    (region.color ?? UIImageHelper.averageColor(of: context.currentImage, at: rect.applying(region.transform))).setFill()
                    context.cgContext.addPath(path)
                    context.cgContext.fillPath()
                case .clipOut:
                    clipOutPath.addPath(path)
                    self.updateClipping(for: context.cgContext,
                                        clipPaths: clipPaths,
                                        clipOutPath: clipOutPath)
                case .clipBegin:
                    clipPaths.append(path)
                    self.updateClipping(for: context.cgContext,
                                        clipPaths: clipPaths,
                                        clipOutPath: clipOutPath)
                case .clipEnd:
                    if !clipPaths.isEmpty {
                        clipPaths.removeLast()
                    }
                    self.updateClipping(for: context.cgContext,
                                        clipPaths: clipPaths,
                                        clipOutPath: clipOutPath)
                }
            }
        }
        return screenshot
    }
    
    private func updateClipping(for context: CGContext, clipPaths: [CGPath], clipOutPath: CGPath) {
        context.resetClip()
        clipPaths.reversed().forEach {
            context.addPath($0)
            context.clip()
        }
    
        context.addPath(clipOutPath)
        context.clip(using: .evenOdd)
    }
    
    @objc(addIgnoreClasses:)
    func addIgnoreClasses(classes: [AnyClass]) {
        redactBuilder.addIgnoreClasses(classes)
    }

    @objc(addRedactClasses:)
    func addRedactClasses(classes: [AnyClass]) {
        redactBuilder.addRedactClasses(classes)
    }

    @objc(setIgnoreContainerClass:)
    func setIgnoreContainerClass(_ containerClass: AnyClass) {
        redactBuilder.setIgnoreContainerClass(containerClass)
    }

    @objc(setRedactContainerClass:)
    func setRedactContainerClass(_ containerClass: AnyClass) {
        redactBuilder.setRedactContainerClass(containerClass)
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    func getRedactBuild() -> UIRedactBuilder {
        redactBuilder
    }
#endif
    
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
