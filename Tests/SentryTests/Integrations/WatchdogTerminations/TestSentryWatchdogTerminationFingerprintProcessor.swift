@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

class TestSentryWatchdogTerminationFingerprintProcessor: SentryWatchdogTerminationFingerprintProcessorWrapper {
    var setFingerprintInvocations = Invocations<[String]?>()
    var clearInvocations = Invocations<Void>()

    override func setFingerprint(_ fingerprint: [String]?) {
        setFingerprintInvocations.record(fingerprint)
    }

    override func clear() {
        clearInvocations.record(())
    }
}
