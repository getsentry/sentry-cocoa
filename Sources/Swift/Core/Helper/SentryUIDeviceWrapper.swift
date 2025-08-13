#if !os(watchOS) && !os(macOS) && !SENTRY_NO_UIKIT
import UIKit

@_spi(Private) @objc public protocol SentryUIDeviceWrapper {
    func start()
    func stop()
    func getSystemVersion() -> String

#if os(iOS)
    var orientation: UIDeviceOrientation { get }
    var isBatteryMonitoringEnabled: Bool { get }
    var batteryState: UIDevice.BatteryState { get }
    var batteryLevel: Float { get }
#endif
}

@_spi(Private) @objc public final class DefaultSentryUIDeviceWrapper: NSObject, SentryUIDeviceWrapper {
    
    let queueWrapper: SentryDispatchQueueWrapper
    
    override convenience init() {
        self.init(queueWrapper: Dependencies.dispatchQueueWrapper)
    }
    
    init(queueWrapper: SentryDispatchQueueWrapper) {
        self.queueWrapper = queueWrapper
    }
    
    @objc public func start() {
        queueWrapper.dispatchAsyncOnMainQueue {
#if os(iOS)
            if !UIDevice.current.isGeneratingDeviceOrientationNotifications {
                self.cleanupDeviceOrientationNotifications = true
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            }
            
            // Needed so we can read the battery level
            if !UIDevice.current.isBatteryMonitoringEnabled {
                self.cleanupBatteryMonitoring = true
                UIDevice.current.isBatteryMonitoringEnabled = true
            }
#endif
            
            self.systemVersion = UIDevice.current.systemVersion
        }
    }
    
    @objc public func stop() {
        #if os(iOS)
        let needsCleanup = self.cleanupDeviceOrientationNotifications
        let needsDisablingBattery = self.cleanupBatteryMonitoring
        let device = UIDevice.current
        queueWrapper.dispatchAsyncOnMainQueue {
            if needsCleanup {
                device.endGeneratingDeviceOrientationNotifications()
            }
            if needsDisablingBattery {
                device.isBatteryMonitoringEnabled = false
            }
        }
        #endif
    }
    
    func dealloc() {
        stop()
    }
    
    #if os(iOS)
    @objc public var orientation: UIDeviceOrientation {
        UIDevice.current.orientation
    }
    
    @objc public var isBatteryMonitoringEnabled: Bool {
        UIDevice.current.isBatteryMonitoringEnabled
    }
    
    @objc public var batteryState: UIDevice.BatteryState {
        UIDevice.current.batteryState
    }
    
    @objc public var batteryLevel: Float {
        UIDevice.current.batteryLevel
    }

    #endif // os(iOS)
    
    @objc public func getSystemVersion() -> String {
        systemVersion
    }
    
    private var systemVersion = ""
    private var cleanupBatteryMonitoring = false
    private var cleanupDeviceOrientationNotifications = false
    
}
#endif
