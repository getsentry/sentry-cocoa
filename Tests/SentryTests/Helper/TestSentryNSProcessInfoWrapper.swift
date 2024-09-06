import Sentry

class TestSentryNSProcessInfoWrapper: SentryNSProcessInfoWrapper {
    struct Override {
        var processorCount: UInt?
        var processDirectoryPath: String?
    }

    var overrides = Override()

    override var processorCount: UInt {
        overrides.processorCount ?? super.processorCount
    }

    override var processDirectoryPath: String {
        overrides.processDirectoryPath ?? super.processDirectoryPath
    }
}
