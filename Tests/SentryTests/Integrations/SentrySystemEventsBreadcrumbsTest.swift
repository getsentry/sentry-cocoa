import XCTest
@testable import Sentry

class SentrySystemEventsBreadcrumbsTest: XCTestCase {
    
    private class Fixture {
        func getSut(scope: Scope, currentDevice: UIDevice = UIDevice.current) -> SentrySystemEventsBreadcrumbs {
            do {
                let options = try Options.init(dict: ["dsn" : "https://username@sentry.io/1"])
                let client = Client.init(options: options)
                let hub = SentryHub.init(client: client, andScope: scope)
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
    
    func testBatteryLevelBreadcrumb() {
        let scope = Scope()
        
        class MyUIDevice : UIDevice {
            override var batteryLevel: Float {
                return 1
            }
            override var batteryState: UIDevice.BatteryState {
                return UIDevice.BatteryState.charging
            }
        }
        
        let currentDevice = MyUIDevice()
        let sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.batteryLevelDidChangeNotification, object: currentDevice))
        
        assertBatteryBreadcrumb(scope: scope, charging: true, level: 100)
    }
    
    func testBatteryUnknownLevelBreadcrumb() {
        let scope = Scope()
        
        class MyUIDevice : UIDevice {
            override var batteryLevel: Float {
                return -1
            }
            override var batteryState: UIDevice.BatteryState {
                return UIDevice.BatteryState.unknown
            }
        }
        
        let currentDevice = MyUIDevice()
        let sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.batteryLevelDidChangeNotification, object: currentDevice))
        
        assertBatteryBreadcrumb(scope: scope, charging: false, level: -1)
    }
    
    func testBatteryChargingStateBreadcrumb() {
        let scope = Scope()
        
        class MyUIDevice : UIDevice {
            override var batteryLevel: Float {
                return 1
            }
            override var batteryState: UIDevice.BatteryState {
                return UIDevice.BatteryState.charging
            }
        }
        
        let currentDevice = MyUIDevice()
        let sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.batteryStateDidChangeNotification, object: currentDevice))
        
        assertBatteryBreadcrumb(scope: scope, charging: true, level: 100)
    }
    
    func testBatteryNotChargingStateBreadcrumb() {
        let scope = Scope()
        
        class MyUIDevice : UIDevice {
            override var batteryLevel: Float {
                return 1
            }
            override var batteryState: UIDevice.BatteryState {
                return UIDevice.BatteryState.unplugged
            }
        }
        
        let currentDevice = MyUIDevice()
        let sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.batteryStateDidChangeNotification, object: currentDevice))
        
        assertBatteryBreadcrumb(scope: scope, charging: false, level: 100)
    }
    
    func assertBatteryBreadcrumb(scope: Scope, charging: Bool, level: Float) {
        let ser = scope.serialize()
        if let breadcrumbs = ser["breadcrumbs"] as? Array<[String: Any]> {
            if let crumb = breadcrumbs.first {
                XCTAssertEqual("device.event", crumb["category"] as? String)
                XCTAssertEqual("system", crumb["type"] as? String)
                XCTAssertEqual("info", crumb["level"] as? String)
                
                if let data = crumb["data"] as? [String: Any] {
                    XCTAssertEqual("BATTERY_STATE_CHANGE", data["action"] as? String)
                    XCTAssertEqual(charging, data["plugged"] as? Bool)
                    // -1 = unknown
                    if (level == -1) {
                        XCTAssertNil(data["level"])
                    } else {
                        XCTAssertEqual(level, data["level"] as? Float)
                    }
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
    
    func testPortraitOrientationBreadcrumb() {
        let scope = Scope()
        
        class MyUIDevice : UIDevice {
            override var orientation: UIDeviceOrientation {
                return UIDeviceOrientation.portrait
            }
        }
        
        let currentDevice = MyUIDevice()
        let sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.orientationDidChangeNotification, object: currentDevice))
        assertPositionOrientationBreadcrumb(position: "portrait", scope: scope)
    }
    
    
    func testLandscapeOrientationBreadcrumb() {
        let scope = Scope()
        
        class MyUIDevice : UIDevice {
            override var orientation: UIDeviceOrientation {
                return UIDeviceOrientation.landscapeLeft
            }
        }
        
        let currentDevice = MyUIDevice()
        let sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.orientationDidChangeNotification, object: currentDevice))
        assertPositionOrientationBreadcrumb(position: "landscape", scope: scope)
    }
    
    func testUnknownOrientationBreadcrumb() {
        let scope = Scope()
        
        class MyUIDevice : UIDevice {
            override var orientation: UIDeviceOrientation {
                return UIDeviceOrientation.unknown
            }
        }
        
        let currentDevice = MyUIDevice()
        let sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.orientationDidChangeNotification, object: currentDevice))
        let ser = scope.serialize()
        if let breadcrumbs = ser["breadcrumbs"] as? Array<[String: Any]> {
            XCTFail("there are breadcrumbs")
        }
    }
    
    func assertPositionOrientationBreadcrumb(position: String, scope: Scope) {
        let ser = scope.serialize()
        if let breadcrumbs = ser["breadcrumbs"] as? Array<[String: Any]> {
            if let crumb = breadcrumbs.first {
                XCTAssertEqual("device.orientation", crumb["category"] as? String)
                XCTAssertEqual("navigation", crumb["type"] as? String)
                XCTAssertEqual("info", crumb["level"] as? String)
                
                if let data = crumb["data"] as? [String: Any] {
                    XCTAssertEqual(position, data["position"] as? String)
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
    
    func testShownKeyboardBreadcrumb() {
        let scope = Scope()
        let sut = fixture.getSut(scope: scope)
        
        NotificationCenter.default.post(Notification(name: UIWindow.keyboardDidShowNotification))
        assertBreadcrumbAction(scope: scope, action: "UIKeyboardDidShowNotification")
    }
    
    func testHiddenKeyboardBreadcrumb() {
        let scope = Scope()
        let sut = fixture.getSut(scope: scope)
        
        NotificationCenter.default.post(Notification(name: UIWindow.keyboardDidHideNotification))
        assertBreadcrumbAction(scope: scope, action: "UIKeyboardDidHideNotification")
    }
    
    func testScreenshotBreadcrumb() {
        let scope = Scope()
        let sut = fixture.getSut(scope: scope)
        
        NotificationCenter.default.post(Notification(name: UIApplication.userDidTakeScreenshotNotification))
        assertBreadcrumbAction(scope: scope, action: "UIApplicationUserDidTakeScreenshotNotification")
    }
    
    func assertBreadcrumbAction(scope: Scope, action: String) {
        let ser = scope.serialize()
        if let breadcrumbs = ser["breadcrumbs"] as? Array<[String: Any]> {
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
}
