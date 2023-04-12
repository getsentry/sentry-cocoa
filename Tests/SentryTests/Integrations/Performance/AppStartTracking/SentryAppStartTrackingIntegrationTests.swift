import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryAppStartTrackingIntegrationTests: NotificationCenterTestCase {
    
    private class Fixture {
        let options = Options()
        let fileManager: SentryFileManager
        
        init() {
            options.tracesSampleRate = 0.1
            options.tracesSampler = { _ in return 0 } 
            options.dsn = TestConstants.dsnAsString(username: "SentryAppStartTrackingIntegrationTests")
            
            fileManager = try! TestFileManager(options: options)
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryAppStartTrackingIntegration!

    override class func setUp() {
        super.setUp()
        SentryLog.configure(true, diagnosticLevel: .debug)
    }
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentrySDK.setAppStartMeasurement(nil)
        sut = SentryAppStartTrackingIntegration()
    }

    override func tearDown() {
        super.tearDown()
        fixture.fileManager.deleteAppState()
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
        SentrySDK.setAppStartMeasurement(nil)
        sut.stop()
    }
    
    func testAppStartMeasuringEnabledAndSampleRate_properlySetupTracker() throws {
        sut.install(with: fixture.options)

        let tracker = try XCTUnwrap(Dynamic(sut).tracker.asObject as? SentryAppStartTracker, "SentryAppStartTrackingIntegration should have a tracker")
        try assertTrackerSetupAndRunning(tracker)
    }

    func testUnistall_stopsTracker() throws {
        sut.install(with: fixture.options)

        let tracker = try XCTUnwrap(Dynamic(sut).tracker.asObject as? SentryAppStartTracker, "SentryAppStartTrackingIntegration should have a tracker")
        try assertTrackerSetupAndRunning(tracker)
        sut.uninstall()
        
        let isRunning = Dynamic(tracker).isRunning.asBool ?? true
        XCTAssertFalse(isRunning, "AppStartTracking should not be running")
    }
    
    func testNoSampleRate_noTracker() {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.tracesSampler = nil
        sut.install(with: options)

        let tracker = Dynamic(sut).tracker.asAnyObject as? SentryAppStartTracker
        XCTAssertNil(tracker)
    }
    
    func testHybridSDKModeEnabled_properlySetupTracker() throws {
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
        
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.tracesSampler = nil
        sut.install(with: options)
        
        let tracker = try XCTUnwrap(Dynamic(sut).tracker.asObject as? SentryAppStartTracker, "SentryAppStartTrackingIntegration should have a tracker")
        try assertTrackerSetupAndRunning(tracker)
    }
    
    func testOnlyAppStartMeasuringEnabled_noTracker() {
        let options = fixture.options
        options.tracesSampleRate = 0.0
        options.tracesSampler = nil
        sut.install(with: options)
        
        let tracker = Dynamic(sut).tracker.asAnyObject as? SentryAppStartTracker
        XCTAssertNil(tracker)
    }
    
    func testAutoPerformanceTrackingDisabled_noTracker() {
        let options = fixture.options
        options.enableAutoPerformanceTracing = false
        sut.install(with: options)
        
        let tracker = Dynamic(sut).tracker.asAnyObject as? SentryAppStartTracker
        XCTAssertNil(tracker)
    }
    
    func test_PerformanceTrackingDisabled() {
        let options = fixture.options
        options.enableAutoPerformanceTracing = false
        let result = sut.install(with: options)
        
        XCTAssertFalse(result)
    }

    func assertTrackerSetupAndRunning(_ tracker: SentryAppStartTracker) throws {
        let dateProvider = Dynamic(tracker).currentDate.asObject as? DefaultCurrentDateProvider

        XCTAssertEqual(dateProvider, DefaultCurrentDateProvider.sharedInstance())

        _ = try XCTUnwrap(Dynamic(tracker).dispatchQueue.asAnyObject as? SentryDispatchQueueWrapper, "Tracker does not have a dispatch queue.")

        let appStateManager = Dynamic(tracker).appStateManager.asObject as? SentryAppStateManager

        XCTAssertEqual(appStateManager, SentryDependencyContainer.sharedInstance().appStateManager)

        _ = try XCTUnwrap(Dynamic(tracker).sysctl.asObject as? SentrySysctl, "Tracker does not have a Sysctl")

        XCTAssertTrue(tracker.isRunning, "AppStartTracking should be running")
    }
    
}
#endif
