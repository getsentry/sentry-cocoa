import Sentry

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class TestSentryUIDeviceWrapper: SentryUIDeviceWrapper {
    var internalOrientation = UIDeviceOrientation.portrait
    var internalIsBatteryMonitoringEnabled = true
    var internalBatteryLevel: Float = 0.6
    var internalBatteryState = UIDevice.BatteryState.charging

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
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
