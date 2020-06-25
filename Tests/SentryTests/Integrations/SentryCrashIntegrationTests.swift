import XCTest

class SentryCrashIntegrationTests: XCTestCase {
    
    // Test for GH-581
    func testReleaseNamePassedToSentryCrash() {
        
        let releaseName = "1.0.0"
        let dist = "14G60"
        // The start of the SDK installs all integrations
        SentrySDK.start(options: ["dsn": TestConstants.dsnAsString,
                                  "release": releaseName,
                                  "dist": dist]
        )
        
        let instance = SentryCrash.sharedInstance()
        let userInfo = (instance?.userInfo ?? ["": ""]) as Dictionary
        assertUserInfoField(userInfo: userInfo, key: "release", expected: releaseName)
        assertUserInfoField(userInfo: userInfo, key: "dist", expected: dist)
    }
    
    private func assertUserInfoField(userInfo: [AnyHashable: Any], key: String, expected: String) {
        if let actual = userInfo[key] as? String {
            XCTAssertEqual(expected, actual)
        } else {
            XCTFail("\(key) not passed to SentryCrash.userInfo")
        }
    }
}
