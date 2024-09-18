import Sentry

class TestSentryNSProcessInfoWrapper: SentryNSProcessInfoWrapper {
    struct Override {
        var processorCount: UInt?
        var processDirectoryPath: String?
        var thermalState: ProcessInfo.ThermalState?
    }

    var overrides = Override()

    override var processorCount: UInt {
        overrides.processorCount ?? super.processorCount
    }

    override var processDirectoryPath: String {
        overrides.processDirectoryPath ?? super.processDirectoryPath
    }

    override var thermalState: ProcessInfo.ThermalState {
        overrides.thermalState ?? super.thermalState
    }
}
