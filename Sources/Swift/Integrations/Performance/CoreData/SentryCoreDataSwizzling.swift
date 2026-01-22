// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentryCoreDataSwizzling: NSObject {
    @objc public static let sharedInstance = SentryCoreDataSwizzling()

    @objc public func start(with tracker: Any) {
        SentryCoreDataSwizzlingHelper.swizzle(withTracker: tracker)
    }

    @objc public func stop() {
        SentryCoreDataSwizzlingHelper.unswizzle()
    }
}
// swiftlint:enable missing_docs
