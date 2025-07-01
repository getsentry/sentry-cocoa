@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

class TestSentryWatchdogTerminationEnvironmentProcessor: SentryWatchdogTerminationEnvironmentProcessorWrapper {
    var setEnvironmentInvocations = Invocations<String?>()
    var clearInvocations = Invocations<Void>()

    override func setEnvironment(_ envrionment: String?) {
        setEnvironmentInvocations.record(envrionment)
    }

    override func clear() {
        clearInvocations.record(())
    }
}
