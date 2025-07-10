@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils

// Note: This file should ideally live in SentryTestUtils, but this would lead to circular imports.
// When refactoring the project structure, consider moving this to SentryTestUtils.

class TestSentryWatchdogTerminationAttributesProcessor: SentryWatchdogTerminationAttributesProcessor {
    var setContextInvocations = Invocations<[String: [String: Any]]?>()
    var setUserInvocations = Invocations<User?>()
    var setDistInvocations = Invocations<String?>()
    var setEnvironmentInvocations = Invocations<String?>()
    var setTagsInvocations = Invocations<[String: String]?>()
    var setExtrasInvocations = Invocations<[String: Any]?>()
    var setFingerprintInvocations = Invocations<[String]?>()
    var clearInvocations = Invocations<Void>()

    override func setContext(_ context: [String: [String: Any]]?) {
        setContextInvocations.record(context)
    }
    
    override func setUser(_ user: User?) {
        setUserInvocations.record(user)
    }
    
    override func setDist(_ dist: String?) {
        setDistInvocations.record(dist)
    }
    
    override func setEnvironment(_ environment: String?) {
        setEnvironmentInvocations.record(environment)
    }
    
    override func setTags(_ tags: [String: String]?) {
        setTagsInvocations.record(tags)
    }
    
    override func setExtras(_ extras: [String: Any]?) {
        setExtrasInvocations.record(extras)
    }
    
    override func setFingerprint(_ fingerprint: [String]?) {
        setFingerprintInvocations.record(fingerprint)
    }

    override func clear() {
        clearInvocations.record(())
    }
}
