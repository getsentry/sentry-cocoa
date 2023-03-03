import Sentry

public class TestSentryNSProcessInfoWrapper: SentryNSProcessInfoWrapper {
    public struct Override {
        public var processorCount: UInt?
    }

    public var overrides = Override()

    public override var processorCount: UInt {
        overrides.processorCount ?? super.processorCount
    }
}
