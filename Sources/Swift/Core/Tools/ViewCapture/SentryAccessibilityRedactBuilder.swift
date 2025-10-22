#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import UIKit
import CoreML
@_implementationOnly import _SentryPrivate
import Vision

@objcMembers
@_spi(Private) public class SentryAccessibilityRedactBuilder: NSObject, SentryUIRedactBuilderProtocol {
    required public init(options: SentryRedactOptions) {
        super.init()
    }

    public func addIgnoreClass(_ ignoreClass: AnyClass) {}

    public func addRedactClass(_ redactClass: AnyClass) {}

    public func addIgnoreClasses(_ ignoreClasses: [AnyClass]) {}

    public func addRedactClasses(_ redactClasses: [AnyClass]) {}

    public func setIgnoreContainerClass(_ containerClass: AnyClass) {}

    public func setRedactContainerClass(_ containerClass: AnyClass) {}

    public func redactRegionsFor(view: UIView, image: UIImage, callback: @escaping ([SentryRedactRegion]?, Error?) -> Void) {
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
