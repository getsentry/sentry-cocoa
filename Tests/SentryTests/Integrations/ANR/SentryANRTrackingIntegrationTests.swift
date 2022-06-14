import XCTest

class SentryANRTrackingIntegrationTests: SentrySDKIntegrationTestsBase {
    
    private class Fixture {
        let options: Options
        
        let currentDate = TestCurrentDateProvider()
                
        init() {
            options = Options()
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 4.5
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryANRTrackingIntegration!
    
    override var options: Options {
        self.fixture.options
    }
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        sut.uninstall()
        super.tearDown()
    }

    func testWhenBeingTraced_TrackerNotInitialized() {
        givenInitializedTracker(isBeingTraced: true)
        XCTAssertNil(Dynamic(sut).tracker.asAnyObject)
    }

    func testWhenNoDebuggerAttached_TrackerInitialized() {
        givenInitializedTracker()
        XCTAssertNotNil(Dynamic(sut).tracker.asAnyObject)
    }
    
    func test_enableAppHangsTracking_Disabled_RemovesEnabledIntegration() {
        let options = Options()
        options.enableAppHangTracking = false
        
        sut = SentryANRTrackingIntegration()
        sut.install(with: options)
        
        let expexted = Options.defaultIntegrations().filter { !$0.contains("ANRTracking") }
        assertArrayEquals(expected: expexted, actual: Array(options.enabledIntegrations))
    }
    
    func test_appHangsTimeoutInterval_Zero_RemovesEnabledIntegration() {
        let options = Options()
        options.enableAppHangTracking = true
        options.appHangTimeoutInterval = 0
        
        sut = SentryANRTrackingIntegration()
        sut.install(with: options)
        
        let expexted = Options.defaultIntegrations().filter { !$0.contains("ANRTracking") }
        assertArrayEquals(expected: expexted, actual: Array(options.enabledIntegrations))
    }
    
    func testANRDetected_EventCaptured() {
        givenInitializedTracker()
        
        Dynamic(sut).anrDetected()
        
        assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNotNil(event)
            guard let ex = event?.exceptions?.first else {
                XCTFail("ANR Exception not found")
                return
            }
            
            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hanging")
            XCTAssertEqual(ex.value, "App hanging for at least 4500 ms.")
            XCTAssertNotNil(ex.stacktrace)
            
            guard let threads = event?.threads else {
                XCTFail("ANR Exception not found")
                return
            }
            
            // Sometimes during tests its possible to have one thread without frames
            // We just need to make sure we retrieve frame information for at least one other thread than the main thread
            let threadsWithFrames = threads.filter {
                ($0.stacktrace?.frames.count ?? 0) >= 1
            }.count
            
            XCTAssertTrue(threadsWithFrames > 1, "Not enough threads with frames")
        }
    }

    private func givenInitializedTracker(isBeingTraced: Bool = false) {
        givenSdkWithHub()
        self.crashWrapper.internalIsBeingTraced = isBeingTraced
        sut = SentryANRTrackingIntegration()
        sut.install(with: self.options)
    }
}
