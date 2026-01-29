import Foundation
@_spi(Private) @testable import Sentry

/// Shared test types for HangTracker tests
struct TestRunLoopObserver: RunLoopObserver { }

struct TestApplicationProvider: ApplicationProvider {
    func application() -> SentryApplication? {
        return nil
    }
}
