import Sentry

public class TestSentryUIDeviceWrapper: SentryUIDeviceWrapper {
#if os(iOS)
    public var internalOrientation = UIDeviceOrientation.portrait
    public var internalIsBatteryMonitoringEnabled = true
    public var internalBatteryLevel: Float = 0.6
    public var internalBatteryState = UIDevice.BatteryState.charging

    public override func orientation() -> UIDeviceOrientation {
        return internalOrientation
    }

    public override func isBatteryMonitoringEnabled() -> Bool {
        return internalIsBatteryMonitoringEnabled
    }

    public override func batteryLevel() -> Float {
        return internalBatteryLevel
    }

    public override func batteryState() -> UIDevice.BatteryState {
        return internalBatteryState
    }
#endif
}
