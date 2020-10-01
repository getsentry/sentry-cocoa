import XCTest

class SentryCrashIntegrationTests: XCTestCase {
    
    private class Fixture {
        
        var session: SentrySession {
            let session = SentrySession(releaseName: "1.0.0")
            session.incrementErrors()
            
            return session
        }
        
        let currentDateProvider = TestCurrentDateProvider()
        let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
        
        var options: Options {
            let options = Options()
            options.dsn = TestConstants.dsnAsString
            return options
        }
        
        var sentryCrash: TestSentryCrashWrapper {
            let sentryCrash = TestSentryCrashWrapper()
            sentryCrash.internalActiveDurationSinceLastCrash = 5.0
            sentryCrash.internalCrashedLastLaunch = true
            return sentryCrash
        }
        
        var hub: SentryHub {
            let client = Client(options: options)
            return TestHub(client: client, andScope: nil)
        }
        
        var fileManager: SentryFileManager {
            return try! SentryFileManager(dsn: TestConstants.dsn, andCurrentDateProvider: TestCurrentDateProvider())
        }
        
        func getSut() -> SentryCrashIntegration {
            return SentryCrashIntegration(crashWrapper: sentryCrash, andDispatchQueueWrapper: dispatchQueueWrapper)
        }
    }
    
    private let fixture = Fixture()
    
    override func setUp() {
        CurrentDate.setCurrentDateProvider(fixture.currentDateProvider)
        
        fixture.fileManager.deleteCurrentSession()
        fixture.fileManager.deleteCrashedSession()
    }
    
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
    
    func testEndSessionAsCrashed_WithCurrentSession() {
        let expectedCrashedSession = givenCurrentSession()
        expectedCrashedSession.endCrashed(withTimestamp: fixture.currentDateProvider.date().addingTimeInterval(5))
        SentrySDK.setCurrentHub(fixture.hub)
        
        advanceTime(bySeconds: 10)
        
        let sut = fixture.getSut()
        sut.install(with: Options())
        
        let crashedSession = fixture.fileManager.readCrashedSession()
        XCTAssertEqual(SentrySessionStatus.crashed, crashedSession?.status)
        XCTAssertEqual(expectedCrashedSession, crashedSession)
        XCTAssertNil(fixture.fileManager.readCurrentSession())
    }
    
    func testEndSessionAsCrashed_NoClientSet() {
        let hub = SentryHub(client: nil, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        let sut = fixture.getSut()
        sut.install(with: Options())
        
        let fileManager = fixture.fileManager
        XCTAssertNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
    }
    
    func testEndSessionAsCrashed_NoCrashLastLaunch() {
        let session = givenCurrentSession()
        
        let sentryCrash = fixture.sentryCrash
        sentryCrash.internalCrashedLastLaunch = false
        let sut = SentryCrashIntegration(crashWrapper: sentryCrash, andDispatchQueueWrapper: fixture.dispatchQueueWrapper)
        sut.install(with: Options())
        
        let fileManager = fixture.fileManager
        XCTAssertEqual(session, fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
    }
    
    func testEndSessionAsCrashed_NoCurrentSession() {
        SentrySDK.setCurrentHub(fixture.hub)
        
        let sut = fixture.getSut()
        sut.install(with: Options())
        
        let fileManager = fixture.fileManager
        XCTAssertNil(fileManager.readCurrentSession())
        XCTAssertNil(fileManager.readCrashedSession())
    }
    
    private func givenCurrentSession() -> SentrySession {
        // serialize sets the timestamp
        let session = SentrySession(jsonObject: fixture.session.serialize())
        fixture.fileManager.storeCurrentSession(session)
        return session
    }
    
    private func assertUserInfoField(userInfo: [AnyHashable: Any], key: String, expected: String) {
        if let actual = userInfo[key] as? String {
            XCTAssertEqual(expected, actual)
        } else {
            XCTFail("\(key) not passed to SentryCrash.userInfo")
        }
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.currentDateProvider.setDate(date: fixture.currentDateProvider.date().addingTimeInterval(bySeconds))
    }
}
