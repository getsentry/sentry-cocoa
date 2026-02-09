// swiftlint:disable missing_docs
#if !os(watchOS) && !os(macOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

@_spi(Private) @objc public protocol SentryUIDeviceWrapper {
    func start()
    func stop()
    func getSystemVersion() -> String
    var currentDevice: UIDevice { get }

#if os(iOS)
    var orientation: UIDeviceOrientation { get }
    var isBatteryMonitoringEnabled: Bool { get }
    var batteryState: UIDevice.BatteryState { get }
    var batteryLevel: Float { get }
#endif
}

@_spi(Private) @objc public final class SentryDefaultUIDeviceWrapper: NSObject, SentryUIDeviceWrapper {
    
    private let queueWrapper: SentryDispatchQueueWrapper
    private var systemVersion = ""
    private var cleanupBatteryMonitoring = false
    private var cleanupDeviceOrientationNotifications = false
    
    // This one shouldn't be used because it acceccess `Dependencies` directly rather than being
    // initialized with dependencies, but since we need to sublcass NSObject it has to be here.
    @available(*, unavailable)
    override convenience init() {
        self.init(queueWrapper: Dependencies.dispatchQueueWrapper)
    }

    @objc public init(queueWrapper: SentryDispatchQueueWrapper) {
        self.queueWrapper = queueWrapper
    }

    @objc public func start() {
        queueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
            guard let self else { return }
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
        queueWrapper.dispatchAsyncOnMainQueueIfNotMainThread {
            if needsCleanup {
                device.endGeneratingDeviceOrientationNotifications()
            }
            if needsDisablingBattery {
                device.isBatteryMonitoringEnabled = false
            }
        }
        #endif
    }
    
    deinit {
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
    
    @objc public var currentDevice: UIDevice {
        UIDevice.current
    }
    
}
#endif
// swiftlint:enable missing_docs
