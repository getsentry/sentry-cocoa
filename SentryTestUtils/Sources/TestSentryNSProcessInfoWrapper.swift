@_spi(Private) import Sentry

@_spi(Private) public final class MockSentryProcessInfo: SentryProcessInfoSource {

    public init() { }
    
    public struct Override {
        public var processorCount: Int?
        public var processDirectoryPath: String?
        public var processPath: String?
        public var thermalState: ProcessInfo.ThermalState?
        public var environment: [String: String]?
        public var isiOSAppOnMac: Bool?
        public var isMacCatalystApp: Bool?
        public var isiOSAppOnVisionOS: Bool?
    }

    public var overrides = Override()

    public var processorCount: Int {
        overrides.processorCount ?? ProcessInfo.processInfo.processorCount
    }

    public var processDirectoryPath: String {
        overrides.processDirectoryPath ?? ProcessInfo.processInfo.processDirectoryPath
    }
    
    public var processPath: String? {
        overrides.processPath ?? ProcessInfo.processInfo.processPath
    }

    public var thermalState: ProcessInfo.ThermalState {
        overrides.thermalState ?? ProcessInfo.processInfo.thermalState
    }
    
    public var environment: [String: String] {
        overrides.environment ?? ProcessInfo.processInfo.environment
    }

    @available(macOS 11.0, *)
    public var isiOSAppOnMac: Bool {
        return overrides.isiOSAppOnMac ?? ProcessInfo.processInfo.isiOSAppOnMac
    }

    @available(macOS 11.0, *)
    public var isMacCatalystApp: Bool {
        return overrides.isMacCatalystApp ?? ProcessInfo.processInfo.isMacCatalystApp
    }
    
    public var isiOSAppOnVisionOS: Bool {
        return overrides.isiOSAppOnVisionOS ?? ProcessInfo.processInfo.isiOSAppOnVisionOS
    }
}
