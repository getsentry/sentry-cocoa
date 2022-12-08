import Sentry

class TestSentrySystemWrapper: SentrySystemWrapper {
    struct Override {
        var memoryFootprintError: NSError?
        var memoryFootprintBytes: mach_vm_size_t?

        var cpuUsageError: NSError?
        var cpuUsagePerCore: [NSNumber]?
    }

    var overrides = Override()

    override func memoryFootprintBytes(_ error: NSErrorPointer) -> mach_vm_size_t {
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
