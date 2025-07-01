@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

class TestSentryWatchdogTerminationLevelProcessor: SentryWatchdogTerminationLevelProcessorWrapper {
    var setLevelInvocations = Invocations<NSNumber?>()
    var clearInvocations = Invocations<Void>()

    override func setLevel(_ level: NSNumber?) {
        setLevelInvocations.record(level)
    }

    override func clear() {
        clearInvocations.record(())
    }
}
