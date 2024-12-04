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
    
    func image(view: UIView, options: SentryRedactOptions, onComplete: @escaping ScreenshotCallback ) {
        let redact = redactBuilder.redactRegionsFor(view: view)
        let image = renderer.render(view: view)
        
        let imageSize = view.bounds.size
        dispatchQueue.dispatchAsync {
            let screenshot = UIGraphicsImageRenderer(size: imageSize, format: .init(for: .init(displayScale: 1))).image { context in
                
                let clipOutPath = CGMutablePath(rect: CGRect(origin: .zero, size: imageSize), transform: nil)
                var clipPaths = [CGPath]()
                
                let imageRect = CGRect(origin: .zero, size: imageSize)
                context.cgContext.addRect(CGRect(origin: CGPoint.zero, size: imageSize))
                context.cgContext.clip(using: .evenOdd)
                UIColor.blue.setStroke()
                
                context.cgContext.interpolationQuality = .none
                image.draw(at: .zero)
                
                var latestRegion: RedactRegion?
                for region in redact {
                    let rect = CGRect(origin: CGPoint.zero, size: region.size)
                    var transform = region.transform
                    let path = CGPath(rect: rect, transform: &transform)
                    
                    defer { latestRegion = region }
                    
                    guard latestRegion?.canReplace(as: region) != true && imageRect.intersects(path.boundingBoxOfPath) else { continue }
                          
                    switch region.type {
                    case .redact, .redactSwiftUI:
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
                        clipPaths.removeLast()
                        self.updateClipping(for: context.cgContext,
                                            clipPaths: clipPaths,
                                            clipOutPath: clipOutPath)
                    }
                }
            }
            onComplete(screenshot)
        }
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

#if TEST || TESTCI
    func getRedactBuild() -> UIRedactBuilder {
        redactBuilder
    }
#endif
    
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
