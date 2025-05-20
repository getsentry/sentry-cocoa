@testable import Sentry
import SentryTestUtils

class TestSentryWatchdogTerminationContextProcessor: SentryWatchdogTerminationContextProcessor {
    var setContextInvocations = Invocations<[AnyHashable: Any]?>()
    var clearInvocations = Invocations<Void>()

    override func setContext(_ context: [String: Any]?) {
        setContextInvocations.record(context)
    }

    override func clear() {
        clearInvocations.record(())
    }
}
