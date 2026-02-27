import SentrySampleShared
import XCTest

final class UIApplicationSwizzleTests: XCTestCase {
  
  // Tests for the crash first reported in https://github.com/getsentry/sentry-cocoa/issues/6966
  func testSendEvent() {
    let app = XCUIApplication()
    app.launchArguments.append(contentsOf: [
        SentrySDKOverrides.Other.disableSpotlight.rawValue
    ])
    app.safelyLaunch()
    
    app.buttons["UIApplication sendEmptyEvent"].tap()
  }
  
}
