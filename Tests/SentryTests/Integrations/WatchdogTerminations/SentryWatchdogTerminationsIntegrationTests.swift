#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import SentryTestUtils
import XCTest

class SentryWatchdogTerminationIntegrationTests: XCTestCase {

    private class Fixture {
        let options: Options
        let client: TestClient!
        let crashWrapper: TestSentryCrashWrapper
        let currentDate = TestCurrentDateProvider()
        let fileManager: SentryFileManager
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        
        init() {
            options = Options()
            
            client = TestClient(options: options)
            
            crashWrapper = TestSentryCrashWrapper.sharedInstance()
            SentryDependencyContainer.sharedInstance().crashWrapper = crashWrapper
            SentryDependencyContainer.sharedInstance().fileManager = try! SentryFileManager(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())

            let hub = SentryHub(client: client, andScope: nil, andCrashWrapper: crashWrapper, andDispatchQueue: SentryDispatchQueueWrapper())
            SentrySDK.setCurrentHub(hub)
            
            fileManager = try! SentryFileManager(options: options, dispatchQueueWrapper: dispatchQueue)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryWatchdogTerminationTrackingIntegration!
    
    override func setUp() {
        super.setUp()
        
        fixture = Fixture()
        fixture.fileManager.store(TestData.appState)
    }
    
    override func tearDown() {
        sut?.uninstall()
        fixture.fileManager.deleteAllFolders()
        clearTestState()
        super.tearDown()
    }
    
    func testWhenUnitTests_TrackerNotInitialized() {
        let sut = SentryWatchdogTerminationTrackingIntegration()
        sut.install(with: Options())
        
        XCTAssertNil(Dynamic(sut).tracker.asAnyObject)
    }
    
    func testWhenNoUnitTests_TrackerInitialized() {
        let sut = SentryWatchdogTerminationTrackingIntegration()
        Dynamic(sut).setTestConfigurationFilePath(nil)
        sut.install(with: Options())
        
        XCTAssertNotNil(Dynamic(sut).tracker.asAnyObject)
    }
    
    func testTestConfigurationFilePath() {
        let sut = SentryWatchdogTerminationTrackingIntegration()
        let path = Dynamic(sut).testConfigurationFilePath.asString
        XCTAssertEqual(path, ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"])
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testANRDetected_UpdatesAppStateToTrue() throws {
        givenInitializedTracker()
        
        Dynamic(sut).anrDetected()

        let appState = try XCTUnwrap(fixture.fileManager.readAppState())
        
        XCTAssertTrue(appState.isANROngoing)
    }
#endif
  
    func testANRStopped_UpdatesAppStateToFalse() {
        givenInitializedTracker()
        
        Dynamic(sut).anrStopped()
        
        guard let appState = fixture.fileManager.readAppState() else {
            XCTFail("appState must not be nil")
            return
        }
        XCTAssertFalse(appState.isANROngoing)
    }
    
    func test_WatchdogTerminationEnabled_DoesInstall() {
        XCTAssertTrue(givenIntegration().install(with: Options()))
    }
    
    func test_WatchdogTerminationDisabled_DoesNotInstall() {
        let sut = givenIntegration()
        let options = Options()
        options.enableWatchdogTerminationTracking = false
        
        XCTAssertFalse(sut.install(with: options))
    }
    
    func test_CrashHandlerDisabled_DoesNotInstall() {
        let sut = givenIntegration()
        let options = Options()
        options.enableCrashHandler = false
        
        XCTAssertFalse(sut.install(with: options))
    }
    
    private func givenIntegration() -> SentryWatchdogTerminationTrackingIntegration {
        let sut = SentryWatchdogTerminationTrackingIntegration()
        Dynamic(sut).setTestConfigurationFilePath(nil)
        return sut
    }
    
    private func givenInitializedTracker(isBeingTraced: Bool = false) {
        fixture.crashWrapper.internalIsBeingTraced = isBeingTraced
        sut = givenIntegration()
        let options = Options()
        sut.install(with: options)
    }
    
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
