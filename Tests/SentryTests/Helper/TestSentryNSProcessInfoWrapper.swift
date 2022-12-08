import Sentry

class TestSentryNSProcessInfoWrapper: SentryNSProcessInfoWrapper {
    struct Override {
        var isLowPowerModeEnabled: Bool?
        var thermalState: ProcessInfo.ThermalState?
    }

    var overrides = Override()

    override var thermalState: ProcessInfo.ThermalState {
        overrides.thermalState ?? super.thermalState
    }

    override var isLowPowerModeEnabled: Bool {
        overrides.isLowPowerModeEnabled ?? super.isLowPowerModeEnabled
    }

    func sendPowerStateChangeNotification() {
        SentryDependencyContainer.sharedInstance().notificationCenterWrapper.postNotificationName(NSNotification.Name.NSProcessInfoPowerStateDidChange, object: ProcessInfo.processInfo)
    }

    func sendThermalStateChangeNotification() {
        SentryDependencyContainer.sharedInstance().notificationCenterWrapper.postNotificationName(ProcessInfo.thermalStateDidChangeNotification, object: ProcessInfo.processInfo)
    }
}
