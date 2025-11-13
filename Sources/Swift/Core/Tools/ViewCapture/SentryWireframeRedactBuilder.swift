#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
@_implementationOnly import _SentryPrivate
import UIKit

@objcMembers
@_spi(Private) public class SentryWireframeRedactBuilder: NSObject, SentryRedactBuilderProtocol {
    struct RenderRegion {
        let frame: CGRect
        let zPosition: CGFloat
        let color: UIColor
    }

    private let options: SentryRedactOptions

    required public init(options: SentryRedactOptions) {
        self.options = options
        super.init()
    }

    public func addIgnoreClass(_ ignoreClass: AnyClass) {
        // no-op
    }

    public func addRedactClass(_ redactClass: AnyClass) {
        // no-op
    }

    public func addIgnoreClasses(_ ignoreClasses: [AnyClass]) {
        // no-op
    }

    public func addRedactClasses(_ redactClasses: [AnyClass]) {
        // no-op
    }

    public func setIgnoreContainerClass(_ ignoreContainerClass: AnyClass) {
        // no-op
    }

    public func setRedactContainerClass(_ redactContainerClass: AnyClass) {
        // no-op
    }

    public func redactRegionsFor(view: UIView, image: UIImage, callback: @escaping ([SentryRedactRegion]?, Error?) -> Void) {
        let regions = getRecursiveRegionsForView(view: view)

        callback(regions.map { region in
            SentryRedactRegion(
                size: region.frame.size,
                transform: CGAffineTransformMakeTranslation(region.frame.minX, region.frame.minY),
                type: .redactOutline,
                color: region.color,
                name: ""
            )
        }, nil)
    }

    func getRecursiveRegionsForView(view: UIView) -> [RenderRegion] {
        var regions: [RenderRegion] = []

        // Add the view itself to the region
        regions.append(RenderRegion(
            frame: view.frame,
            zPosition: view.layer.zPosition,
            color: getColorForView(view: view)
        ))

        regions += getRecursiveRegionsForLayer(layer: view.layer)

        // Traverse all subview
        for subview in view.subviews {
            regions += getRecursiveRegionsForView(view: subview)
        }
        
        return regions
    }

    func getColorForView(view: UIView) -> UIColor {
        if let label = view as? UILabel {
            return label.textColor
        }
        return view.backgroundColor ?? UIColor.black
    }

    func getRecursiveRegionsForLayer(layer: CALayer) -> [RenderRegion] {
        var regions: [RenderRegion] = []

        // Add the layer itself to the region
        regions.append(RenderRegion(
            frame: layer.frame,
            zPosition: layer.zPosition,
            color: getColorForLayer(layer: layer)
        ))

        // Traverse all sublayers
        for sublayer in layer.sublayers ?? [] {
            regions += getRecursiveRegionsForLayer(layer: sublayer)
        }

        return regions
    }

    func getColorForLayer(layer: CALayer) -> UIColor {
        if let backgroundColor = layer.backgroundColor {
            return UIColor(cgColor: backgroundColor)
        }
        if let fillColor = (layer as? CAShapeLayer)?.fillColor {
            return UIColor(cgColor: fillColor)
        }
        return UIColor.black
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
