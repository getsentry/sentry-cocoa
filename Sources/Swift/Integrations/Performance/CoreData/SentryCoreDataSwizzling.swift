// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate

final class SentryCoreDataSwizzling: NSObject {
    func start(with tracker: Any) {
        SentryCoreDataSwizzlingHelper.swizzle(withTracker: tracker)
    }

    func stop() {
#if SENTRY_TEST || SENTRY_TEST_CI
        SentryCoreDataSwizzlingHelper.unswizzle()
#endif
    }
}
// swiftlint:enable missing_docs
