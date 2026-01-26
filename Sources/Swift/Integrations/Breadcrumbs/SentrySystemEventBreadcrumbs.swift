@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit

final class SentrySystemEventBreadcrumbs: NSObject {
    private weak var delegate: SentryBreadcrumbDelegate?

    private let currentDeviceProvider: SentryUIDeviceWrapperProvider
    private let fileManager: SentryFileManager
    private let notificationCenterWrapper: SentryNSNotificationCenterWrapper
    private let dateProvider: SentryCurrentDateProvider
    
    // Track whether we enabled these device notifications so we can disable them on stop
    private var didEnableBatteryMonitoring = false
    private var didBeginGeneratingOrientationNotifications = false

    init(
        currentDeviceProvider: SentryUIDeviceWrapperProvider,
        fileManager: SentryFileManager,
        notificationCenterWrapper: SentryNSNotificationCenterWrapper,
        dateProvider: SentryCurrentDateProvider = SentryDependencyContainer.sharedInstance().dateProvider
    ) {
        self.currentDeviceProvider = currentDeviceProvider
        self.fileManager = fileManager
        self.notificationCenterWrapper = notificationCenterWrapper
        self.dateProvider = dateProvider
        super.init()
    }

    deinit {
        // In dealloc it's safe to unsubscribe for all, see
        // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
        notificationCenterWrapper.removeObserver(self, name: nil, object: nil)
    }

    func start(with delegate: SentryBreadcrumbDelegate) {
        self.delegate = delegate
        initBatteryObserver(currentDeviceProvider.uiDeviceWrapper.currentDevice)
        initOrientationObserver(currentDeviceProvider.uiDeviceWrapper.currentDevice)
        initKeyboardVisibilityObserver()
        initScreenshotObserver()
        initTimezoneObserver()
        initSignificantTimeChangeObserver()
    }

    func timezoneEventTriggered() {
        timezoneEventTriggered(storedTimezoneOffset: nil)
    }

    func stop() {
        // Remove the observers with the most specific detail possible, see
        // https://developer.apple.com/documentation/foundation/nsnotificationcenter/1413994-removeobserver
        notificationCenterWrapper.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        notificationCenterWrapper.removeObserver(self, name: UIResponder.keyboardDidHideNotification, object: nil)
        notificationCenterWrapper.removeObserver(self, name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        notificationCenterWrapper.removeObserver(self, name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        notificationCenterWrapper.removeObserver(self, name: UIDevice.batteryStateDidChangeNotification, object: nil)
        notificationCenterWrapper.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        notificationCenterWrapper.removeObserver(self, name: UIApplication.significantTimeChangeNotification, object: nil)
        notificationCenterWrapper.removeObserver(self, name: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil)
        
        // Disable device notifications that we enabled
        let currentDevice = currentDeviceProvider.uiDeviceWrapper.currentDevice
        if didEnableBatteryMonitoring {
            currentDevice.isBatteryMonitoringEnabled = false
            didEnableBatteryMonitoring = false
        }
        if didBeginGeneratingOrientationNotifications {
            currentDevice.endGeneratingDeviceOrientationNotifications()
            didBeginGeneratingOrientationNotifications = false
        }
    }

    // MARK: - Battery Observer

    private func initBatteryObserver(_ currentDevice: UIDevice) {
        if !currentDevice.isBatteryMonitoringEnabled {
            currentDevice.isBatteryMonitoringEnabled = true
            didEnableBatteryMonitoring = true
        }

        // Posted when the battery level changes.
        notificationCenterWrapper.addObserver(
            self,
            selector: #selector(batteryStateChanged(_:)),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: currentDevice
        )

        // Posted when battery state changes.
        notificationCenterWrapper.addObserver(
            self,
            selector: #selector(batteryStateChanged(_:)),
            name: UIDevice.batteryStateDidChangeNotification,
            object: currentDevice
        )
    }

    @objc private func batteryStateChanged(_ notification: Notification) {
        // Notifications for battery level change are sent no more frequently than once per minute
        guard let currentDevice = notification.object as? UIDevice else {
            SentrySDKLog.debug("UIDevice of NSNotification was nil. Won't create battery changed breadcrumb.")
            return
        }

        let batteryData = getBatteryStatus(currentDevice)

        let crumb = Breadcrumb(level: .info, category: "device.event")
        crumb.type = "system"
        crumb.data = batteryData
        delegate?.add(crumb)
    }

    private func getBatteryStatus(_ currentDevice: UIDevice) -> [String: Any] {
        // borrowed and adapted from
        // https://github.com/apache/cordova-plugin-battery-status/blob/master/src/ios/CDVBattery.m
        let currentState = currentDevice.batteryState

        var isPlugged = false // UIDeviceBatteryStateUnknown or UIDeviceBatteryStateUnplugged
        if currentState == .charging || currentState == .full {
            isPlugged = true
        }
        let currentLevel = currentDevice.batteryLevel
        var batteryData: [String: Any] = [:]

        // W3C spec says level must be null if it is unknown
        if currentState != .unknown && currentLevel != -1.0 {
            let w3cLevel = currentLevel * 100
            batteryData["level"] = NSNumber(value: w3cLevel)
        } else {
            SentrySDKLog.debug("batteryLevel is unknown.")
        }

        batteryData["plugged"] = isPlugged
        batteryData["action"] = "BATTERY_STATE_CHANGE"

        return batteryData
    }

    // MARK: - Orientation Observer

    private func initOrientationObserver(_ currentDevice: UIDevice) {
        if !currentDevice.isGeneratingDeviceOrientationNotifications {
            currentDevice.beginGeneratingDeviceOrientationNotifications()
            didBeginGeneratingOrientationNotifications = true
        }

        // Posted when the orientation of the device changes.
        notificationCenterWrapper.addObserver(
            self,
            selector: #selector(orientationChanged(_:)),
            name: UIDevice.orientationDidChangeNotification,
            object: currentDevice
        )
    }

    @objc private func orientationChanged(_ notification: Notification) {
        guard let currentDevice = notification.object as? UIDevice else {
            return
        }

        let crumb = Breadcrumb(level: .info, category: "device.orientation")
        let currentOrientation = currentDevice.orientation

        // Ignore changes in device orientation if unknown, face up, or face down.
        if !currentOrientation.isValidInterfaceOrientation {
            SentrySDKLog.debug("currentOrientation is unknown.")
            return
        }

        if currentOrientation.isLandscape {
            crumb.data = ["position": "landscape"]
        } else {
            crumb.data = ["position": "portrait"]
        }
        crumb.type = "navigation"
        delegate?.add(crumb)
    }

    // MARK: - Keyboard Visibility Observer

    private func initKeyboardVisibilityObserver() {
        // Posted immediately after the display of the keyboard.
        notificationCenterWrapper.addObserver(
            self,
            selector: #selector(systemEventTriggered(_:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )

        // Posted immediately after the dismissal of the keyboard.
        notificationCenterWrapper.addObserver(
            self,
            selector: #selector(systemEventTriggered(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
    }

    @objc private func systemEventTriggered(_ notification: Notification) {
        let crumb = Breadcrumb(level: .info, category: "device.event")
        crumb.type = "system"
        crumb.data = ["action": notification.name.rawValue]
        delegate?.add(crumb)
    }

    // MARK: - Screenshot Observer

    private func initScreenshotObserver() {
        // it's only about the action, but not the SS itself
        notificationCenterWrapper.addObserver(
            self,
            selector: #selector(systemEventTriggered(_:)),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }

    // MARK: - Timezone Observer

    private func initTimezoneObserver() {
        // Detect if the stored timezone is different from the current one;
        // if so, then we also send a breadcrumb
        let storedTimezoneOffset = fileManager.readTimezoneOffset()

        if storedTimezoneOffset == nil {
            updateStoredTimezone()
        } else if let storedOffset = storedTimezoneOffset?.intValue,
                  storedOffset != dateProvider.timezoneOffset() {
            timezoneEventTriggered(storedTimezoneOffset: storedTimezoneOffset)
        }

        // Posted when the timezone of the device changed
        notificationCenterWrapper.addObserver(
            self,
            selector: #selector(timezoneEventTriggeredNotification),
            name: NSNotification.Name.NSSystemTimeZoneDidChange,
            object: nil
        )
    }

    @objc private func timezoneEventTriggeredNotification() {
        timezoneEventTriggered(storedTimezoneOffset: nil)
    }

    private func timezoneEventTriggered(storedTimezoneOffset: NSNumber?) {
        let storedOffset = storedTimezoneOffset ?? fileManager.readTimezoneOffset()

        let crumb = Breadcrumb(level: .info, category: "device.event")
        let offset = dateProvider.timezoneOffset()

        crumb.type = "system"

        var dataDict: [String: Any] = [
            "action": "TIMEZONE_CHANGE",
            "current_seconds_from_gmt": Int64(offset)
        ]

        if let storedOffset = storedOffset {
            dataDict["previous_seconds_from_gmt"] = storedOffset
        }

        crumb.data = dataDict
        delegate?.add(crumb)

        updateStoredTimezone()
    }

    private func updateStoredTimezone() {
        fileManager.storeTimezoneOffset(dateProvider.timezoneOffset())
    }

    // MARK: - Significant Time Change Observer

    private func initSignificantTimeChangeObserver() {
        notificationCenterWrapper.addObserver(
            self,
            selector: #selector(significantTimeChangeTriggered(_:)),
            name: UIApplication.significantTimeChangeNotification,
            object: nil
        )
    }

    /**
     * The system posts this notification when, for example, there's a change to a new day (midnight), a
     * carrier time update, or a change to, or from, daylight savings time. The notification doesn't
     * contain a user info dictionary.
     *
     * @see
     * https://developer.apple.com/documentation/uikit/uiapplication/significanttimechangenotification#Discussion
     */
    @objc private func significantTimeChangeTriggered(_ notification: Notification) {
        let crumb = Breadcrumb(level: .info, category: "device.event")
        crumb.type = "system"

        // We don't add the timezone here, because we already add it in timezoneEventTriggered.
        crumb.data = ["action": "SIGNIFICANT_TIME_CHANGE"]

        delegate?.add(crumb)
    }
}

#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
