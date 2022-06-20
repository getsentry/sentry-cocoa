import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryANRTrackingIntegrationTests: XCTestCase {
    
    private static let dsn = TestConstants.dsnAsString(username: "SentryANRTrackingIntegrationTests")
    
    private class Fixture {
        let options: Options
        let client: TestClient!
        let crashWrapper: TestSentryCrashWrapper
        let currentDate = TestCurrentDateProvider()
        let fileManager: SentryFileManager
        
        init() {
            options = Options()
            options.dsn = SentryANRTrackingIntegrationTests.dsn
    
            client = TestClient(options: options)
            
            crashWrapper = TestSentryCrashWrapper.sharedInstance()
            SentryDependencyContainer.sharedInstance().crashWrapper = crashWrapper

            let hub = SentryHub(client: client, andScope: nil, andCrashWrapper: crashWrapper, andCurrentDateProvider: currentDate)
            SentrySDK.setCurrentHub(hub)
            
            fileManager = try! SentryFileManager(options: options, andCurrentDateProvider: currentDate)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryANRTrackingIntegration!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        fixture.fileManager.store(TestData.appState)
    }
    
    override func tearDown() {
        super.tearDown()
        sut.uninstall()
        fixture.fileManager.deleteAllFolders()
        clearTestState()
    }

    func testWhenBeingTraced_TrackerNotInitialized() {
        givenInitializedTracker(isBeingTraced: true)

        XCTAssertNil(Dynamic(sut).tracker.asAnyObject)
    }

    func testWhenNoDebuggerAttached_TrackerInitialized() {
        givenInitializedTracker()

        XCTAssertNotNil(Dynamic(sut).tracker.asAnyObject)
    }
    
    func test_OOMDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.enableOutOfMemoryTracking = false
        
        sut = SentryANRTrackingIntegration()
        sut.install(with: options)
        
        let expexted = Options.defaultIntegrations().filter { !$0.contains("ANRTracking") }
        assertArrayEquals(expected: expexted, actual: Array(options.enabledIntegrations))
    }
    
    func testANRDetected_UpdatesAppStateToTrue() {
        givenInitializedTracker()
        
        Dynamic(sut).anrDetected()
        
        guard let appState = fixture.fileManager.readAppState() else {
            XCTFail("appState must not be nil")
            return
        }

        XCTAssertTrue(appState.isANROngoing)
    }
    
    func testANRStopped_UpdatesAppStateToFalse() {
        givenInitializedTracker()
        
        Dynamic(sut).anrStopped()
        
        guard let appState = fixture.fileManager.readAppState() else {
            XCTFail("appState must not be nil")
            return
        }
        XCTAssertFalse(appState.isANROngoing)
    }

    private func givenInitializedTracker(isBeingTraced: Bool = false) {
        fixture.crashWrapper.internalIsBeingTraced = isBeingTraced
        sut = SentryANRTrackingIntegration()
        let options = Options()
        Dynamic(sut).setTestConfigurationFilePath(nil)
        sut.install(with: options)
    }
}

#endif
