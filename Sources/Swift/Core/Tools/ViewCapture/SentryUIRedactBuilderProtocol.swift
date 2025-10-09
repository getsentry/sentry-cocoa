#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import UIKit

@objc @_spi(Private) public protocol SentryUIRedactBuilderProtocol {
    init(options: SentryRedactOptions)
    func redactRegionsFor(view: UIView, image: UIImage, callback: @escaping ([SentryRedactRegion]?, Error?) -> Void)
    func addIgnoreClass(_ ignoreClass: AnyClass)
    func addRedactClass(_ redactClass: AnyClass)
    func addIgnoreClasses(_ ignoreClasses: [AnyClass])
    func addRedactClasses(_ redactClasses: [AnyClass])
    func setIgnoreContainerClass(_ containerClass: AnyClass)
    func setRedactContainerClass(_ containerClass: AnyClass)

}
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
#endif // os(iOS) || os(tvOS)
