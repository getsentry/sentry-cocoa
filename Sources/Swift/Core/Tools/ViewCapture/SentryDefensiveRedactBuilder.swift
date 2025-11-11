#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
@_implementationOnly import _SentryPrivate
import UIKit

@objcMembers
@_spi(Private) public class SentryDefensiveRedactBuilder: NSObject, SentryUIRedactBuilderProtocol {

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
        callback(nil, nil)
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT
