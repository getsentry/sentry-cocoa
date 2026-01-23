// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

final class SentryNSFileManagerSwizzling: NSObject {
    func start(withOptions options: Options, tracker: SentryFileIOTracker) {
        guard options.enableSwizzling else {
            SentrySDKLog.debug("Auto-tracking of NSFileManager is disabled because enableSwizzling is false")
            return
        }

        guard options.enableFileManagerSwizzling else {
            SentrySDKLog.debug("Auto-tracking of NSFileManager is disabled because enableFileManagerSwizzling is false")
            return
        }

        SentryNSFileManagerSwizzlingHelper.swizzle(withTracker: tracker)
    }

    func stop() {
        SentryNSFileManagerSwizzlingHelper.unswizzle()
    }
}

// swiftlint:enable missing_docs
