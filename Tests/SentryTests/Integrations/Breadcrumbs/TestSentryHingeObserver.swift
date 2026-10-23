#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

#if os(iOS)
/// A hinge observer double with a settable current state and no UIKit dependency.
final class TestSentryHingeObserver: SentryHingeObserving {
    var currentState: SentryHingeState?
    private(set) var startInvocations = 0
    private(set) var stopInvocations = 0

    func start(handler: @escaping (SentryHingeState) -> Void) {
        startInvocations += 1
    }

    func stop() {
        stopInvocations += 1
        currentState = nil
    }
}
#endif // os(iOS)
