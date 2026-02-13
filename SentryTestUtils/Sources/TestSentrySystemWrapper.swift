@_spi(Private) import Sentry

#if os(iOS) || os(macOS)

class TestSentrySystemWrapper: SentrySystemWrapper {
    override init(processorCount: Int = 4) {
        super.init(processorCount: processorCount)
    }

    struct Override {
        var memoryFootprintError: NSError?
        var memoryFootprintBytes: mach_vm_size_t?

        var cpuUsageError: NSError?
        var cpuUsage: NSNumber?

        var cpuEnergyUsageError: NSError?
        var cpuEnergyUsage: NSNumber?
    }

    var overrides = Override()

    override func memoryFootprintBytes(_ error: NSErrorPointer) -> mach_vm_size_t {
        if let errorOverride = overrides.memoryFootprintError {
            error?.pointee = errorOverride
            return 0
        }
        return overrides.memoryFootprintBytes ?? super.memoryFootprintBytes(error)
    }

    override func cpuUsage() throws -> NSNumber {
        if let errorOverride = overrides.cpuUsageError {
            throw errorOverride
        }
        return try overrides.cpuUsage ?? super.cpuUsage()
    }

#if arch(arm) || arch(arm64)
    override func cpuEnergyUsage() throws -> NSNumber {
        if let errorOverride = overrides.cpuEnergyUsageError {
            throw errorOverride
        }
        return try overrides.cpuEnergyUsage ?? super.cpuEnergyUsage()
    }
#endif
}
#endif // os(iOS) || os(macOS)
