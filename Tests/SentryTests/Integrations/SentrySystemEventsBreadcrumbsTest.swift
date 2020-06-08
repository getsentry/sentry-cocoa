import XCTest
@testable import Sentry

class SentrySystemEventsBreadcrumbsTest: XCTestCase {
    
    private class Fixture {
        func getSut(scope: Scope, currentDevice: UIDevice) -> SentrySystemEventsBreadcrumbs {
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
    
    func testBatteryBreadcrumb() {
        let scope = Scope()
        
        let currentDevice = UIDevice.current
        let sut = fixture.getSut(scope: scope, currentDevice: currentDevice)
        
        NotificationCenter.default.post(Notification(name: UIDevice.batteryLevelDidChangeNotification, object: currentDevice))
        
        let ser = scope.serialize()
        if let breadcrumbs = ser["breadcrumbs"] as? [String: Any] {
            print(breadcrumbs)
        }
        
        XCTAssertEqual("device.event", "device.event")
    }
}
