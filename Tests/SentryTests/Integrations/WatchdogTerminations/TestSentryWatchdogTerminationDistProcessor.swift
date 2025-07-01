@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

class TestSentryWatchdogTerminationDistProcessor: SentryWatchdogTerminationDistProcessorWrapper {
    var setDistInvocations = Invocations<String?>()
    var clearInvocations = Invocations<Void>()

    override func setDist(_ dist: String?) {
        setDistInvocations.record(dist)
    }

    override func clear() {
        clearInvocations.record(())
    }
}
