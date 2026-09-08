#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate

#if os(iOS) || os(macOS)

@_spi(Private) public class TestSentrySystemWrapper: SentrySystemWrapper {
    public struct Override {
        public var memoryFootprintError: NSError?
        public var memoryFootprintBytes: NSNumber?

        public var cpuUsageError: NSError?
        public var cpuUsage: NSNumber?

        public var cpuEnergyUsageError: NSError?
        public var cpuEnergyUsage: NSNumber?
    }

    public var overrides = Override()

    public convenience init() {
        self.init(processorCount: 1)
    }

    public override func memoryFootprintBytes() throws -> NSNumber {
        if let errorOverride = overrides.memoryFootprintError {
            throw errorOverride
        }
        return try overrides.memoryFootprintBytes ?? super.memoryFootprintBytes()
    }

    public override func cpuUsage() throws -> NSNumber {
        if let errorOverride = overrides.cpuUsageError {
            throw errorOverride
        }
        return try overrides.cpuUsage ?? super.cpuUsage()
    }

#if arch(arm) || arch(arm64)
    public override func cpuEnergyUsage() throws -> NSNumber {
        if let errorOverride = overrides.cpuEnergyUsageError {
            throw errorOverride
        }
        return try overrides.cpuEnergyUsage ?? super.cpuEnergyUsage()
    }
#endif
}
#endif // os(iOS) || os(macOS)
