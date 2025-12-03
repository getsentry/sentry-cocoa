import XCTest
import SentrySampleShared

final class UIApplicationSwizzleTests: XCTestCase {
  
  func testSendEvent() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: [
        SentrySDKOverrides.Other.disableSpotlight.rawValue,
    ])
    app.safelyLaunch()
    
    app.buttons["UIApplication sendEvent"].tap()
  }
  
}
