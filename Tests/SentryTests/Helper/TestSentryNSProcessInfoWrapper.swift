import Sentry

class TestSentryNSProcessInfoWrapper: SentryNSProcessInfoWrapper {
    struct Override {
        var isLowPowerModeEnabled: Bool?
        var thermalState: ProcessInfo.ThermalState?
        var processorCount: UInt
    }

    var overrides = Override()

    override var thermalState: ProcessInfo.ThermalState {
        overrides.thermalState ?? super.thermalState
    }

    override var isLowPowerModeEnabled: Bool {
        overrides.isLowPowerModeEnabled ?? super.isLowPowerModeEnabled
    }

    override var processorCount: UInt {
        overrides.processorCount ?? super.processorCount
    }

    @available(iOS 9.0, macOS 12.0, *)
    func sendPowerStateChangeNotification() {
        SentryDependencyContainer.sharedInstance().notificationCenterWrapper.postNotificationName(NSNotification.Name.NSProcessInfoPowerStateDidChange, object: ProcessInfo.processInfo)
    }

    func sendThermalStateChangeNotification() {
        SentryDependencyContainer.sharedInstance().notificationCenterWrapper.postNotificationName(ProcessInfo.thermalStateDidChangeNotification, object: ProcessInfo.processInfo)
    }
}
