import Sentry

public class TestSentryNSProcessInfoWrapper: SentryNSProcessInfoWrapper {
    public struct Override {
        public var processorCount: UInt?
        public var processDirectoryPath: String?
        public var thermalState: ProcessInfo.ThermalState?
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
}
