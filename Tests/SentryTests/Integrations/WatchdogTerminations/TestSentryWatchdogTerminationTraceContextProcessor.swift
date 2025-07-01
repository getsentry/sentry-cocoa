@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

class TestSentryWatchdogTerminationTraceContextProcessor: SentryWatchdogTerminationTraceContextProcessorWrapper {
    var setTraceContextInvocations = Invocations<[String: Any]?>()
    var clearInvocations = Invocations<Void>()

    override func setTraceContext(_ traceContext: [String: Any]?) {
        setTraceContextInvocations.record(traceContext)
    }

    override func clear() {
        clearInvocations.record(())
    }
}
