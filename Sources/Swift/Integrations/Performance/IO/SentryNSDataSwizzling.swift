// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

@_spi(Private) @objc public final class SentryNSDataSwizzling: NSObject {
    @objc public func start(withOptions options: Options, tracker: SentryFileIOTracker) {
        guard options.enableSwizzling else {
            SentrySDKLog.debug("Auto-tracking of NSData is disabled because enableSwizzling is false")
            return
        }

        guard options.enableDataSwizzling else {
            SentrySDKLog.debug("Auto-tracking of NSData is disabled because enableDataSwizzling is false")
            return
        }

        SentryNSDataSwizzlingHelper.swizzle(withTracker: tracker)
    }

    @objc public func stop() {
        SentryNSDataSwizzlingHelper.unswizzle()
    }
}
// swiftlint:enable missing_docs
