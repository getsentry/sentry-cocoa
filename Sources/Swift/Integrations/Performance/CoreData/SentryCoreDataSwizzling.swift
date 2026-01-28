// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

final class SentryCoreDataSwizzling: NSObject {
    func start(with tracker: Any) {
        SentryCoreDataSwizzlingHelper.swizzle(withTracker: tracker)
    }

    func stop() {
        SentryCoreDataSwizzlingHelper.stop()
    }
}
// swiftlint:enable missing_docs
