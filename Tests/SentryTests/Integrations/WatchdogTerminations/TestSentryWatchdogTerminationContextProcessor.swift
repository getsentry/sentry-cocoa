@testable import Sentry
import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

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
