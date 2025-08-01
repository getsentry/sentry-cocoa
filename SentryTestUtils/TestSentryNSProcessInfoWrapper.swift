import Sentry

public class TestSentryNSProcessInfoWrapper: SentryNSProcessInfoWrapper {
    public struct Override {
        public var processorCount: UInt?
        public var processDirectoryPath: String?
        public var thermalState: ProcessInfo.ThermalState?
        public var environment: [String: String]?
        public var isiOSAppOnMac: Bool?
        public var isMacCatalystApp: Bool?
    }

    public var overrides = Override()

    public override var processorCount: UInt {
        overrides.processorCount ?? super.processorCount
    }

    public override var processDirectoryPath: String {
        overrides.processDirectoryPath ?? super.processDirectoryPath
    }

    public override var thermalState: ProcessInfo.ThermalState {
        overrides.thermalState ?? super.thermalState
    }
    
    public override var environment: [String: String] {
        overrides.environment ?? super.environment
    }

    @available(iOS 14.0, macOS 11.0, tvOS 14.0, *)
    public override var isiOSAppOnMac: Bool {
        return overrides.isiOSAppOnMac ?? super.isiOSAppOnMac
    }

    @available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
    public override var isMacCatalystApp: Bool {
        return overrides.isMacCatalystApp ?? super.isMacCatalystApp
    }
}
