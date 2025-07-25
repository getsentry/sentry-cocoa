@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentrySystemEventBreadcrumbsTest: XCTestCase {
    
    // This feature only works on iOS
    #if os(iOS)
    
    private class Fixture {
        let options: Options
        let delegate = SentryBreadcrumbTestDelegate()
        let fileManager: TestFileManager
        var currentDateProvider = TestCurrentDateProvider()
        let notificationCenterWrapper = TestNSNotificationCenterWrapper()

        init() {
            options = Options()
            options.dsn = TestConstants.dsnAsString(username: "SentrySystemEventBreadcrumbsTest")
            options.releaseName = "SentrySessionTrackerIntegrationTests"
            options.sessionTrackingIntervalMillis = 10_000
            options.environment = "debug"
            SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider

            fileManager = try! TestFileManager(options: options)
        }

        func getSut(currentDevice: UIDevice? = UIDevice.current) -> SentrySystemEventBreadcrumbs {
            let systemEvents = SentrySystemEventBreadcrumbs(
                fileManager: fileManager,
                andNotificationCenterWrapper: notificationCenterWrapper
            )
            systemEvents.start(with: self.delegate, currentDevice: currentDevice)
            
            return systemEvents
        }
    }
    
    private class MyUIDevice: UIDevice {
        private var _batteryLevel: Float
        private var _batteryState: UIDevice.BatteryState
        private var _orientation: UIDeviceOrientation
        
        init(batteryLevel: Float = 1, batteryState: UIDevice.BatteryState = UIDevice.BatteryState.charging, orientation: UIDeviceOrientation = UIDeviceOrientation.portrait) {
            self._batteryLevel = batteryLevel
            self._batteryState = batteryState
            self._orientation = orientation
        }
        
        override var batteryLevel: Float {
            return _batteryLevel
        }
        override var batteryState: UIDevice.BatteryState {
            return _batteryState
        }
        override var orientation: UIDeviceOrientation {
            return _orientation
        }
    }

    private var fixture: Fixture!
    private var sut: SentrySystemEventBreadcrumbs!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
        fixture.fileManager.deleteTimezoneOffset()
        sut.stop()
    }
    
    func testBatteryLevelBreadcrumb() {
        let currentDevice = MyUIDevice(batteryLevel: 0.56, batteryState: UIDevice.BatteryState.full)
        
        sut = fixture.getSut(currentDevice: currentDevice)
        
        _ = fixture.getSut(currentDevice: currentDevice)
        
        postBatteryLevelNotification(uiDevice: currentDevice)
        
        assertBatteryBreadcrumb( charging: true, level: 56)
    }
    
    func testBatteryUnknownLevelBreadcrumb() {
        let currentDevice = MyUIDevice(batteryLevel: -1, batteryState: UIDevice.BatteryState.unknown)
        
        sut = fixture.getSut(currentDevice: currentDevice)
        
        postBatteryLevelNotification(uiDevice: currentDevice)
        
        assertBatteryBreadcrumb(charging: false, level: -1)
    }
    
    func testBatteryNotUnknownButNoLevelBreadcrumb() {
        let currentDevice = MyUIDevice(batteryLevel: -1, batteryState: UIDevice.BatteryState.full)
        
        sut = fixture.getSut(currentDevice: currentDevice)
        
        postBatteryLevelNotification(uiDevice: currentDevice)
        
        assertBatteryBreadcrumb(charging: true, level: -1)
    }
    
    func testBatteryChargingStateBreadcrumb() {
        let currentDevice = MyUIDevice()
        
        sut = fixture.getSut(currentDevice: currentDevice)
        
        postBatteryLevelNotification(uiDevice: currentDevice)
        
        assertBatteryBreadcrumb(charging: true, level: 100)
    }
    
    func testBatteryNotChargingStateBreadcrumb() {
        let currentDevice = MyUIDevice(batteryState: UIDevice.BatteryState.unplugged)
        
        sut = fixture.getSut(currentDevice: currentDevice)
        
        fixture.notificationCenterWrapper.post(Notification(name: UIDevice.batteryStateDidChangeNotification, object: currentDevice))

        assertBatteryBreadcrumb(charging: false, level: 100)
    }
    
    func testBatteryUIDeviceNilNotification() {
        let currentDevice = MyUIDevice()
        
        sut = fixture.getSut(currentDevice: currentDevice)
        
        postBatteryLevelNotification(uiDevice: nil)
        
        XCTAssertEqual(self.fixture.delegate.addCrumbInvocations.count, 0)
    }
    
    func testBatteryBreadcrumbForSessionReplay() throws {
        let currentDevice = MyUIDevice()
        sut = fixture.getSut(currentDevice: currentDevice)
        postBatteryLevelNotification(uiDevice: currentDevice)
        
        guard let breadcrumb = fixture.delegate.addCrumbInvocations.first else {
            XCTFail("No battery breadcrumb")
            return
        }
        
        let sut = SentrySRDefaultBreadcrumbConverter()
        let result = try XCTUnwrap(sut.convert(from: breadcrumb) as? SentryRRWebBreadcrumbEvent)
        let crumbData = try XCTUnwrap(result.data)
        let payload = try XCTUnwrap(crumbData["payload"] as? [String: Any])
        let payloadData = try XCTUnwrap(payload["data"] as? [String: Any])
        
        XCTAssertEqual(payload["category"] as? String, "device.battery")
        XCTAssertEqual(payloadData["level"] as? Double, 100.0)
        XCTAssertEqual(payloadData["charging"] as? Bool, true)
    }
    
    private func assertBatteryBreadcrumb(charging: Bool, level: Float) {
        
        XCTAssertEqual(1, fixture.delegate.addCrumbInvocations.count)
            
        if let crumb = fixture.delegate.addCrumbInvocations.first {
            
            XCTAssertEqual("device.event", crumb.category)
            XCTAssertEqual("system", crumb.type)
            XCTAssertEqual(SentryLevel.info, crumb.level)
            
            XCTAssertNotNil(crumb.data, "no breadcrumb.data")
            
            if let data = crumb.data {
                
                XCTAssertEqual("BATTERY_STATE_CHANGE", data["action"] as? String)
                XCTAssertEqual(charging, data["plugged"] as? Bool)
                // -1 = unknown
                if level == -1 {
                    XCTAssertNil(data["level"])
                } else {
                    XCTAssertEqual(level, data["level"] as? Float)
                }
            }
        }
    }
    
    func testPortraitOrientationBreadcrumb() {
        let currentDevice = MyUIDevice()
        
        sut = fixture.getSut(currentDevice: currentDevice)
        
        fixture.notificationCenterWrapper.post(Notification(name: UIDevice.orientationDidChangeNotification, object: currentDevice))
        assertPositionOrientationBreadcrumb(position: "portrait")
    }
    
    func testLandscapeOrientationBreadcrumb() {
        let currentDevice = MyUIDevice(orientation: UIDeviceOrientation.landscapeLeft)
        
        sut = fixture.getSut(currentDevice: currentDevice)
        
        fixture.notificationCenterWrapper.post(Notification(name: UIDevice.orientationDidChangeNotification, object: currentDevice))
        assertPositionOrientationBreadcrumb(position: "landscape")
    }
    
    func testUnknownOrientationBreadcrumb() {
        let currentDevice = MyUIDevice(orientation: UIDeviceOrientation.unknown)
        
        sut = fixture.getSut(currentDevice: currentDevice)
        
        fixture.notificationCenterWrapper.post(Notification(name: UIDevice.orientationDidChangeNotification, object: currentDevice))

        XCTAssertEqual(0, fixture.delegate.addCrumbInvocations.count, "there are breadcrumbs")
    }
    
    func testOrientationBreadcrumbForSessionReplay() throws {
        let currentDevice = MyUIDevice()
        sut = fixture.getSut(currentDevice: currentDevice)
        fixture.notificationCenterWrapper.post(Notification(name: UIDevice.orientationDidChangeNotification, object: currentDevice))
        
        guard let breadcrumb = fixture.delegate.addCrumbInvocations.first else {
            XCTFail("No orientation breadcrumb")
            return
        }
        
        let sut = SentrySRDefaultBreadcrumbConverter()
        let result = try XCTUnwrap(sut.convert(from: breadcrumb))
        
        let event = result.serialize()
        let eventData = event["data"] as? [String: Any]
        let eventPayload = eventData?["payload"] as? [String: Any]
        let payloadData = eventPayload?["data"] as? [String: Any]
        
        XCTAssertEqual(event["type"] as? Int, 5)
        XCTAssertEqual(eventData?["tag"] as? String, "breadcrumb")
        XCTAssertEqual(eventPayload?["category"] as? String, "device.orientation")
        XCTAssertEqual(payloadData?["position"] as? String, "portrait")
    }
    
    private func assertPositionOrientationBreadcrumb(position: String) {
        XCTAssertEqual(1, fixture.delegate.addCrumbInvocations.count)
        
        if let crumb = fixture.delegate.addCrumbInvocations.first {
            XCTAssertEqual("device.orientation", crumb.category)
            XCTAssertEqual("navigation", crumb.type)
            XCTAssertEqual(SentryLevel.info, crumb.level)
            
            XCTAssertNotNil(crumb.data, "no breadcrumb.data")
            
            if let data = crumb.data {
                XCTAssertEqual(position, data["position"] as? String)
            }
        }
        
    }
    
    func testShownKeyboardBreadcrumb() {
        sut = fixture.getSut(currentDevice: nil)
        
        NotificationCenter.default.post(Notification(name: UIWindow.keyboardDidShowNotification))
        
        Dynamic(sut).systemEventTriggered(Notification(name: UIWindow.keyboardDidShowNotification))
        
        assertBreadcrumbAction( action: "UIKeyboardDidShowNotification")
    }
    
    func testHiddenKeyboardBreadcrumb() {
        sut = fixture.getSut(currentDevice: nil)
        
        Dynamic(sut).systemEventTriggered(Notification(name: UIWindow.keyboardDidHideNotification))
        
        assertBreadcrumbAction(action: "UIKeyboardDidHideNotification")
    }
    
    func testScreenshotBreadcrumb() {
        sut = fixture.getSut(currentDevice: nil)
        
        Dynamic(sut).systemEventTriggered(Notification(name: UIApplication.userDidTakeScreenshotNotification))
        
        assertBreadcrumbAction(action: "UIApplicationUserDidTakeScreenshotNotification")
    }

    func testTimezoneFirstTimeNilNoBreadcrumb() {
        fixture.currentDateProvider.timezoneOffsetValue = 7_200

        sut = fixture.getSut(currentDevice: nil)

        XCTAssertEqual(0, fixture.delegate.addCrumbInvocations.count)
    }

    func testTimezoneChangeInitialBreadcrumb() {
        fixture.fileManager.storeTimezoneOffset(0)
        fixture.currentDateProvider.timezoneOffsetValue = 7_200

        sut = fixture.getSut(currentDevice: nil)

        assertBreadcrumbAction(action: "TIMEZONE_CHANGE") { data in
            XCTAssertEqual(data["previous_seconds_from_gmt"] as? Int, 0)
            XCTAssertEqual(data["current_seconds_from_gmt"] as? Int64, 7_200)
        }
    }

    func testTimezoneChangeNotificationBreadcrumb() {
        sut = fixture.getSut(currentDevice: nil)

        fixture.currentDateProvider.timezoneOffsetValue = 7_200

        sut.timezoneEventTriggered()

        assertBreadcrumbAction(action: "TIMEZONE_CHANGE") { data in
            XCTAssertEqual(data["previous_seconds_from_gmt"] as? Int, 0)
            XCTAssertEqual(data["current_seconds_from_gmt"] as? Int64, 7_200)
        }
    }
    
    func testTimezoneChangeNotificationBreadcrumb_NoStoredTimezoneOffset() {
        sut = fixture.getSut(currentDevice: nil)

        fixture.currentDateProvider.timezoneOffsetValue = 7_200
        fixture.fileManager.deleteTimezoneOffset()

        sut.timezoneEventTriggered()

        assertBreadcrumbAction(action: "TIMEZONE_CHANGE") { data in
            XCTAssertNil(data["previous_seconds_from_gmt"])
            XCTAssertEqual(data["current_seconds_from_gmt"] as? Int64, 7_200)
        }
    }

    func testStopCallsSpecificRemoveObserverMethods() {
        sut = fixture.getSut(currentDevice: nil)
        sut.stop()
        XCTAssertEqual(fixture.notificationCenterWrapper.removeObserverWithNameAndObjectInvocations.count, 6)
    }
    
    private func postBatteryLevelNotification(uiDevice: UIDevice?) {
        Dynamic(sut).batteryStateChanged(Notification(name: UIDevice.batteryLevelDidChangeNotification, object: uiDevice))
    }

    private func assertBreadcrumbAction(action: String, checks: (([String: Any]) -> Void)? = nil) {
        XCTAssertEqual(1, fixture.delegate.addCrumbInvocations.count)
        
        if let crumb = fixture.delegate.addCrumbInvocations.first {
       
            XCTAssertEqual("device.event", crumb.category)
            XCTAssertEqual("system", crumb.type)
            XCTAssertEqual(SentryLevel.info, crumb.level)
            
            if let data = crumb.data {
                XCTAssertEqual(action, data["action"] as? String)
                checks?(data)
            } else {
                XCTFail("no breadcrumb.data")
            }
        }
    }
    
    #endif
}
