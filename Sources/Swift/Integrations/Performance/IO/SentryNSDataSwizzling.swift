// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

final class SentryNSDataSwizzling: NSObject {
    func start(withOptions options: Options, tracker: SentryFileIOTracker) {
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

    func stop() {
        SentryNSDataSwizzlingHelper.stop()
    }
}
// swiftlint:enable missing_docs
