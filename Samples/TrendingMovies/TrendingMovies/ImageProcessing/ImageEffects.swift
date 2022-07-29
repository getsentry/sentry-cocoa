import UIKit

struct ImageEffects {
    static func createBlurredBackdrop(image: UIImage,
                                      downsamplingFactor: CGFloat = 1.0,
                                      blurRadius: CGFloat,
                                      tintColor: UIColor? = nil,
                                      saturationDeltaFactor: CGFloat = 1.0) -> UIImage? {
        let span = Tracer.startSpan(name: "create-blurred-backdrop")
        span.annotate(key: "width", value: String(Double(image.size.width)))
        span.annotate(key: "height", value: String(Double(image.size.height)))
        span.annotate(key: "blurRadius", value: String(Double(blurRadius)))
        span.annotate(key: "downsamplingFactor", value: String(Double(downsamplingFactor)))
        span.annotate(key: "saturationDeltaFactor", value: String(Double(saturationDeltaFactor)))
        defer { span.end() }

        let containerLayer = CALayer()
        containerLayer.frame = CGRect(origin: .zero, size: image.size)
        containerLayer.backgroundColor = UIColor.clear.cgColor

        let downsampledSize = CGSize(width: image.size.width * downsamplingFactor, height: image.size.height * downsamplingFactor)
        let blurLayer = CALayer()
        blurLayer.bounds = CGRect(origin: .zero, size: downsampledSize)
        blurLayer.position = CGPoint(x: containerLayer.bounds.midX, y: containerLayer.bounds.midY)
        blurLayer.contents = image.cgImage
        blurLayer.masksToBounds = false
        containerLayer.addSublayer(blurLayer)

        UIGraphicsBeginImageContextWithOptions(containerLayer.bounds.size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            fatalError("Could not get graphics context")
        }
        containerLayer.render(in: context)
        guard let contextImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return nil
        }
        UIGraphicsEndImageContext()
        return UIImageEffects.imageByApplyingBlur(to: contextImage, withRadius: blurRadius, tintColor: tintColor, saturationDeltaFactor: saturationDeltaFactor, maskImage: nil)
    }
}
