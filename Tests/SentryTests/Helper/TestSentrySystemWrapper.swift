import Sentry

class TestSentrySystemWrapper: SentrySystemWrapper {
    struct Override {
        var memoryFootprintError: NSError?
        var memoryFootprintBytes: SentryRAMBytes?

        var cpuUsageError: NSError?
        var cpuUsagePerCore: [NSNumber]?
    }

    var overrides = Override()

    override init() {
        super.init(dispatchSourceFactory: TestSentryDispatchSourceFactory())
    }

    override func memoryFootprintBytes(_ error: NSErrorPointer) -> SentryRAMBytes {
        if let errorOverride = overrides.memoryFootprintError {
            error?.pointee = errorOverride
            return 0
        }
        return overrides.memoryFootprintBytes ?? super.memoryFootprintBytes(error)
    }

    override func cpuUsagePerCore() throws -> [NSNumber] {
        if let errorOverride = overrides.cpuUsageError {
            throw errorOverride
        }
        return try overrides.cpuUsagePerCore ?? super.cpuUsagePerCore()
    }
}
