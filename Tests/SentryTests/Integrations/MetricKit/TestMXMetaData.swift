#if os(iOS) || os(macOS) || os(visionOS)
import MetricKit

@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXMetaData: MXMetaData {
    struct Override {
        var osVersion = ""
        var applicationBuildVersion = ""
        var pid: pid_t = 0
        var lowPowerModeEnabled = false
        var isTestFlightApp = false
        var bundleIdentifier = ""
    }

    public var overrides = Override()

    override var osVersion: String {
        return overrides.osVersion
    }

    @available(iOS 17.0, macOS 14.0, *)
    override var pid: pid_t {
        return overrides.pid
    }

    @available(iOS 17.0, macOS 14.0, *)
    override var lowPowerModeEnabled: Bool {
        return overrides.lowPowerModeEnabled
    }

    @available(iOS 17.0, macOS 14.0, *)
    override var isTestFlightApp: Bool {
        return overrides.isTestFlightApp
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    override var bundleIdentifier: String {
        return overrides.bundleIdentifier
    }
    #endif // compiler(>=6.2)

    override var applicationBuildVersion: String {
        return overrides.applicationBuildVersion
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
