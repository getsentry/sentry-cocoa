@testable import Sentry
import XCTest

class SentrySystemEventsBreadcrumbsTest: XCTestCase {
    
    // This feature only works on iOS
    #if os(iOS)
    
    private class Fixture {
        func getSut(scope: Scope, currentDevice: UIDevice? = UIDevice.current) -> SentrySystemEventsBreadcrumbs {
            do {
                let options = try Options(dict: ["dsn": "https://username@sentry.io/1"])
                let client = Client(options: options)
                let hub = SentryHub(client: client, andScope: scope)
                SentrySDK.setCurrentHub(hub)
            } catch {
                XCTFail("Failed to setup test")
            }
            
            let systemEvents = SentrySystemEventsBreadcrumbs()
            systemEvents.start(currentDevice)
            return systemEvents
        }
    }
    
    private let fixture = Fixture()
    private var sut: SentrySystemEventsBreadcrumbs!
    
    internal class MyUIDevice: UIDevice {
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
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testBatteryLevelBreadcrumb() {
        let currentDevice = MyUIDevice(batteryLevel: 0.56, batteryState: UIDevice.BatteryState.full)
        
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.batteryLevelDidChangeNotification, object: currentDevice))
        
        assertBatteryBreadcrumb(scope: scope, charging: true, level: 56)
    }
    
    func testBatteryUnknownLevelBreadcrumb() {
        let currentDevice = MyUIDevice(batteryLevel: -1, batteryState: UIDevice.BatteryState.unknown)
        
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.batteryLevelDidChangeNotification, object: currentDevice))
        
        assertBatteryBreadcrumb(scope: scope, charging: false, level: -1)
    }
    
    func testBatteryNotUnknownButNoLevelBreadcrumb() {
        let currentDevice = MyUIDevice(batteryLevel: -1, batteryState: UIDevice.BatteryState.full)
        
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.batteryLevelDidChangeNotification, object: currentDevice))
        
        assertBatteryBreadcrumb(scope: scope, charging: true, level: -1)
    }
    
    func testBatteryChargingStateBreadcrumb() {
        let currentDevice = MyUIDevice()
        
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.batteryStateDidChangeNotification, object: currentDevice))
        
        assertBatteryBreadcrumb(scope: scope, charging: true, level: 100)
    }
    
    func testBatteryNotChargingStateBreadcrumb() {
        let currentDevice = MyUIDevice(batteryState: UIDevice.BatteryState.unplugged)
        
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.batteryStateDidChangeNotification, object: currentDevice))
        
        assertBatteryBreadcrumb(scope: scope, charging: false, level: 100)
    }
    
    private func assertBatteryBreadcrumb(scope: Scope, charging: Bool, level: Float) {
        let ser = scope.serialize()
        
        XCTAssertNotNil(ser["breadcrumbs"] as? [[String: Any]], "no scope.breadcrumbs")
        
        if let breadcrumbs = ser["breadcrumbs"] as? [[String: Any]] {
            
            XCTAssertNotNil(breadcrumbs.first, "scope.breadcrumbs is empty")
            
            if let crumb = breadcrumbs.first {
                
                XCTAssertEqual("device.event", crumb["category"] as? String)
                XCTAssertEqual("system", crumb["type"] as? String)
                XCTAssertEqual("info", crumb["level"] as? String)
                
                XCTAssertNotNil(crumb["data"] as? [String: Any], "no breadcrumb.data")
                
                if let data = crumb["data"] as? [String: Any] {
                    
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
    }
    
    func testPortraitOrientationBreadcrumb() {
        let currentDevice = MyUIDevice()
        
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.orientationDidChangeNotification, object: currentDevice))
        assertPositionOrientationBreadcrumb(position: "portrait", scope: scope)
    }
    
    func testLandscapeOrientationBreadcrumb() {
        let currentDevice = MyUIDevice(orientation: UIDeviceOrientation.landscapeLeft)
        
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.orientationDidChangeNotification, object: currentDevice))
        assertPositionOrientationBreadcrumb(position: "landscape", scope: scope)
    }
    
    func testUnknownOrientationBreadcrumb() {
        let currentDevice = MyUIDevice(orientation: UIDeviceOrientation.unknown)
        
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.orientationDidChangeNotification, object: currentDevice))
        let ser = scope.serialize()
        
        XCTAssertNil(ser["breadcrumbs"], "there are breadcrumbs")
    }
    
    private func assertPositionOrientationBreadcrumb(position: String, scope: Scope) {
        let ser = scope.serialize()
        
        XCTAssertNotNil(ser["breadcrumbs"] as? [[String: Any]], "no scope.breadcrumbs")
        
        if let breadcrumbs = ser["breadcrumbs"] as? [[String: Any]] {
            
            XCTAssertNotNil(breadcrumbs.first, "scope.breadcrumbs is empty")
            
            if let crumb = breadcrumbs.first {
                XCTAssertEqual("device.orientation", crumb["category"] as? String)
                XCTAssertEqual("navigation", crumb["type"] as? String)
                XCTAssertEqual("info", crumb["level"] as? String)
                
                XCTAssertNotNil(crumb["data"] as? [String: Any], "no breadcrumb.data")
                
                if let data = crumb["data"] as? [String: Any] {
                    XCTAssertEqual(position, data["position"] as? String)
                }
            }
        }
    }
    
    func testShownKeyboardBreadcrumb() {
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: nil)
        
        NotificationCenter.default.post(Notification(name: UIWindow.keyboardDidShowNotification))
        assertBreadcrumbAction(scope: scope, action: "UIKeyboardDidShowNotification")
    }
    
    func testHiddenKeyboardBreadcrumb() {
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: nil)
        
        NotificationCenter.default.post(Notification(name: UIWindow.keyboardDidHideNotification))
        assertBreadcrumbAction(scope: scope, action: "UIKeyboardDidHideNotification")
    }
    
    func testScreenshotBreadcrumb() {
        let scope = Scope()
        sut = fixture.getSut(scope: scope, currentDevice: nil)
        
        NotificationCenter.default.post(Notification(name: UIApplication.userDidTakeScreenshotNotification))
        assertBreadcrumbAction(scope: scope, action: "UIApplicationUserDidTakeScreenshotNotification")
    }
    
    private func assertBreadcrumbAction(scope: Scope, action: String) {
        let ser = scope.serialize()
        if let breadcrumbs = ser["breadcrumbs"] as? [[String: Any]] {
            if let crumb = breadcrumbs.first {
                XCTAssertEqual("device.event", crumb["category"] as? String)
                XCTAssertEqual("system", crumb["type"] as? String)
                XCTAssertEqual("info", crumb["level"] as? String)
                
                if let data = crumb["data"] as? [String: Any] {
                    XCTAssertEqual(action, data["action"] as? String)
                } else {
                    XCTFail("no breadcrumb.data")
                }
            } else {
                XCTFail("scope.breadcrumbs is empty")
            }
        } else {
            XCTFail("no scope.breadcrumbs")
        }
    }
    
    #endif
}
