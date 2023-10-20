import Sentry

#if os(iOS) || targetEnvironment(macCatalyst)
class TestSentryUIDeviceWrapper: SentryUIDeviceWrapper {
    var internalOrientation = UIDeviceOrientation.portrait
    var internalIsBatteryMonitoringEnabled = true
    var internalBatteryLevel: Float = 0.6
    var internalBatteryState = UIDevice.BatteryState.charging
    var started = false

    override func start() {
        started = true
    }
    override func stop() {
        started = false
    }

    override func orientation() -> UIDeviceOrientation {
        return internalOrientation
    }

    override func isBatteryMonitoringEnabled() -> Bool {
        return internalIsBatteryMonitoringEnabled
    }

    override func batteryLevel() -> Float {
        return internalBatteryLevel
    }

    override func batteryState() -> UIDevice.BatteryState {
        return internalBatteryState
    }
}
#endif // os(iOS) || targetEnvironment(macCatalyst)
