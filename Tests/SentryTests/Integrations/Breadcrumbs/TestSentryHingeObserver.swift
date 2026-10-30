#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

#if os(iOS) && !targetEnvironment(macCatalyst)
/// A hinge observer double with a settable current state and no UIKit dependency.
final class TestSentryHingeObserver: SentryHingeObserving {
    var currentState: SentryHingeState?
    private(set) var handlers: [SentryHingeObserverToken: SentryHingeObserverHandler] = [:]
    private(set) var addObserverInvocations = 0
    private(set) var removeObserverInvocations = 0

    func addObserver(_ handler: @escaping SentryHingeObserverHandler) -> SentryHingeObserverToken {
        addObserverInvocations += 1
        let token = SentryHingeObserverToken()
        handlers[token] = handler
        return token
    }

    func removeObserver(token: SentryHingeObserverToken) {
        removeObserverInvocations += 1
        handlers.removeValue(forKey: token)
        if handlers.isEmpty {
            currentState = nil
        }
    }

    func simulateUpdate(status: SentryHingeStatus, degrees: Double) {
        let state = SentryHingeState(status: status, angle: degrees * .pi / 180)
        currentState = state
        for handler in handlers.values {
            handler(state)
        }
    }
}
#endif // os(iOS) && !targetEnvironment(macCatalyst)
