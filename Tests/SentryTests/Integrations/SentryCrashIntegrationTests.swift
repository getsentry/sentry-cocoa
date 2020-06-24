import XCTest

class SentryCrashIntegrationTests: XCTestCase {

    // Test for GH-581
    func testReleaseNamePassedToSentryCrash() {
        
        let releaseName = "1.0.0"
        // The start of the SDK installs all integrations
        SentrySDK.start(options: ["dsn": TestConstants.dsnAsString,
                                  "release": releaseName])
        
        let instance = SentryCrash.sharedInstance()
        let userInfo = (instance?.userInfo ?? ["": ""]) as Dictionary
        if let actual = userInfo["release"] as? String {
            XCTAssertEqual(releaseName, actual)
        } else {
            XCTFail("Release not passed to SentryCrash.userInfo")
        }
    }
}
