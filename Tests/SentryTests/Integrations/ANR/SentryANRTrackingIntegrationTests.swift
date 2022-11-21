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
    
    func test_enableAppHangsTracking_Disabled() {
        let options = Options()
        options.enableAppHangTracking = false
        
        sut = SentryANRTrackingIntegration()
        let result = sut.install(with: options)

        XCTAssertFalse(result)
    }
    
    func test_appHangsTimeoutInterval_Zero() {
        let options = Options()
        options.enableAppHangTracking = true
        options.appHangTimeoutInterval = 0
        
        sut = SentryANRTrackingIntegration()
        let result = sut.install(with: options)
        
        XCTAssertFalse(result)
    }
    
    func testANRDetected_EventCaptured() {
        givenInitializedTracker()
        setUpThreadInspector()
        
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
            XCTAssertEqual(ex.stacktrace?.frames.first?.function, "main")
            XCTAssertTrue(event?.threads?[0].current?.boolValue ?? false)
            
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
    
    private func setUpThreadInspector() {
        let threadInspector = TestThreadInspector.instance
        
        let frame1 = Sentry.Frame()
        frame1.function = "Second_frame_function"
        
        let thread1 = Sentry.Thread(threadId: 0)
        thread1.stacktrace = Stacktrace(frames: [frame1], registers: [:])
        thread1.current = true
        
        let frame2 = Sentry.Frame()
        frame2.function = "main"
        
        let thread2 = Sentry.Thread(threadId: 1)
        thread2.stacktrace = Stacktrace(frames: [frame2], registers: [:])
        thread2.current = false
        
        threadInspector.allThreads = [
            thread2,
            thread1
        ]
        
        SentrySDK.currentHub().getClient()?.threadInspector = threadInspector
    }
}
