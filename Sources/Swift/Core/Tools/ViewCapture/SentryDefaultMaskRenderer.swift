#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)

import UIKit

class SentryDefaultMaskRenderer: NSObject, SentryMaskRenderer {
    func maskScreenshot(screenshot image: UIImage, size: CGSize, masking: [SentryRedactRegion]) -> UIImage {
        let image = UIGraphicsImageRenderer(size: size, format: .init(for: .init(displayScale: 1))).image { context in
            applyMasking(to: context, image: image, size: size, masking: masking)
        }
        return image
    }

    func applyMasking(
        to context: SentryMaskRendererContext,
        image: UIImage,
        size: CGSize,
        masking: [SentryRedactRegion]
    ) {
        let imageRect = CGRect(origin: .zero, size: size)
        var clipPaths = [CGPath]()
        var clipOutPaths = [CGMutablePath(rect: imageRect, transform: nil)]
        
        context.cgContext.addRect(imageRect)
        context.cgContext.clip(using: .evenOdd)

        context.cgContext.interpolationQuality = .none
        image.draw(at: .zero)

        var latestRegion: SentryRedactRegion?
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
                if let currentClipOutPath = clipOutPaths.last {
                    currentClipOutPath.addPath(path)
                }
                self.updateClipping(for: context.cgContext,
                                    clipPaths: clipPaths,
                                    clipOutPaths: clipOutPaths)
            case .clipBegin:
                clipPaths.append(path)
                clipOutPaths.append(CGMutablePath())
                self.updateClipping(for: context.cgContext,
                                    clipPaths: clipPaths,
                                    clipOutPaths: clipOutPaths)
            case .clipEnd:
                if !clipPaths.isEmpty {
                    clipPaths.removeLast()
                }
                if clipOutPaths.count > 1 {
                    clipOutPaths.removeLast()
                }
                self.updateClipping(for: context.cgContext,
                                    clipPaths: clipPaths,
                                    clipOutPaths: clipOutPaths)
            }
        }
    }

    private func updateClipping(
        for context: CGContext,
        clipPaths: [CGPath],
        clipOutPaths: [CGMutablePath]
    ) {
        context.resetClip()
        clipPaths.reversed().forEach {
            context.addPath($0)
            context.clip()
        }

        // `addPath` appends each input as a subpath (it doesn't do a geometric union).
        // The final even-odd clip is then evaluated across all subpaths together.
        let combinedClipOutPath = CGMutablePath()
        clipOutPaths.forEach { combinedClipOutPath.addPath($0) }

        context.addPath(combinedClipOutPath)
        context.clip(using: .evenOdd)
    }
}

// Implement the SentryMaskRendererContext protocol for UIGraphicsImageRendererContext to make it replaceable
extension UIGraphicsImageRendererContext: SentryMaskRendererContext {}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
