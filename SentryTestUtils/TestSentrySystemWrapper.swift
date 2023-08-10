import Sentry

public class TestSentrySystemWrapper: SentrySystemWrapper {
    public struct Override {
        public var memoryFootprintError: NSError?
        public var memoryFootprintBytes: SentryRAMBytes?

        public var cpuUsageError: NSError?
        public var cpuUsage: NSNumber?
    }

    public var overrides = Override()

    public override func memoryFootprintBytes(_ error: NSErrorPointer) -> SentryRAMBytes {
        if let errorOverride = overrides.memoryFootprintError {
            error?.pointee = errorOverride
            return 0
        }
        return overrides.memoryFootprintBytes ?? super.memoryFootprintBytes(error)
    }

    public override func cpuUsage() throws -> NSNumber {
        if let errorOverride = overrides.cpuUsageError {
            throw errorOverride
        }
        return try overrides.cpuUsage ?? super.cpuUsage()
    }
}
