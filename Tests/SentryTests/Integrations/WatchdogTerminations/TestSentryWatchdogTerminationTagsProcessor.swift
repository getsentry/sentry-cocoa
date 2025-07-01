@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

class TestSentryWatchdogTerminationTagsProcessor: SentryWatchdogTerminationTagsProcessorWrapper {
    var setTagsInvocations = Invocations<[String: String]?>()
    var clearInvocations = Invocations<Void>()

    override func setTags(_ tags: [String: String]?) {
        setTagsInvocations.record(tags)
    }

    override func clear() {
        clearInvocations.record(())
    }
}
