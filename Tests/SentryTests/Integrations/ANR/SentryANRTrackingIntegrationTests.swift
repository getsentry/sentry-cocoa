import XCTest

class SentryANRTrackingIntegrationTests: SentrySDKIntegrationTestsBase {
    
    private class Fixture {
        let options: Options
        
        let currentDate = TestCurrentDateProvider()
                
        init() {
            options = Options()
            options.enableANRTracking = true
            options.anrTimeoutInterval = 4.5
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
    
    func test_OOMDisabled_RemovesEnabledIntegration() {
        let options = Options()
        options.enableANRTracking = false
        
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
            
            XCTAssertEqual(ex.mechanism?.type, "anr")
            XCTAssertEqual(ex.type, "App Hanging")
            XCTAssertEqual(ex.value, "Application Not Responding for at least 4500 ms.")
            
            guard let threads = event?.threads else {
                XCTFail("ANR Exception not found")
                return
            }
            
            //Sometimes during tests its possible to have one thread without frames
            //We just need to make sure we retrieve frame information for at least one other thread than the main thread
            var threadsWithFrames = 0
            
            for thr in threads {
                if (thr.stacktrace?.frames.count ?? 0) >= 1 {
                    threadsWithFrames += 1
                }
            }
            
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
