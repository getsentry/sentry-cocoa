import Sentry

class TestSentryNSProcessInfoWrapper: SentryNSProcessInfoWrapper {
    struct Override {
        var processorCount: UInt?
    }

    var overrides = Override()

    override var processorCount: UInt {
        overrides.processorCount ?? super.processorCount
    }
}
