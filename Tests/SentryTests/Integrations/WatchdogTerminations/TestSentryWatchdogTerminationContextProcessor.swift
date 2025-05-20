@testable import Sentry
import SentryTestUtils

class TestSentryWatchdogTerminationContextProcessor: SentryWatchdogTerminationContextProcessor {
    var setContextInvocations = Invocations<[String: [String: Any]]?>()
    var clearInvocations = Invocations<Void>()

    override func setContext(_ context: [String: [String: Any]]?) {
        setContextInvocations.record(context)
    }

    override func clear() {
        clearInvocations.record(())
    }
}
