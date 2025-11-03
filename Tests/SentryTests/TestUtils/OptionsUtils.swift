@testable import Sentry

@objc extension Options {
    // Exposes the `toInternal` function to ObjC
    @objc public func toInternalOptions() -> SentryOptionsInternal {
        self.toInternal()
    }
}
