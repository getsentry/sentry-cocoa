import UIKit

class SentryDefaultMaskRenderer: NSObject, SentryMaskRenderer {
    func maskScreenshot(screenshot image: UIImage, size: CGSize, masking: [RedactRegion]) -> UIImage {
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
}
