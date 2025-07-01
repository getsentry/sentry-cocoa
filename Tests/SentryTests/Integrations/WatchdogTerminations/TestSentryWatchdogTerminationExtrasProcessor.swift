@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

class TestSentryWatchdogTerminationExtrasProcessor: SentryWatchdogTerminationExtrasProcessorWrapper {
    var setExtrasInvocations = Invocations<[String: Any]?>()
    var clearInvocations = Invocations<Void>()

    override func setExtras(_ extras: [String: Any]?) {
        setExtrasInvocations.record(extras)
    }

    override func clear() {
        clearInvocations.record(())
    }
}
