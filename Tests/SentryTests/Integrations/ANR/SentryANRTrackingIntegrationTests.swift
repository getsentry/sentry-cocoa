import SentryTestUtils
import XCTest
import Nimble

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
        sut?.uninstall()
        clearTestState()
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
            
            expect(ex.mechanism?.type) == "AppHang"
            expect(ex.type) == "App Hanging"
            expect(ex.value) == "App hanging for at least 4500 ms."
            expect(ex.stacktrace) != nil
            expect(ex.stacktrace?.frames.first?.function) == "main"
            expect(ex.stacktrace?.snapshot?.boolValue) == true
            expect(event?.threads?[0].current?.boolValue) == true
            expect(event?.isAppHangEvent) == true
            
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
    
    func testANRDetected_ButNoThreads_EventNotCaptured() {
        givenInitializedTracker()
        setUpThreadInspector(addThreads: false)
        
        Dynamic(sut).anrDetected()
        
        assertNoEventCaptured()
    }
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testANRDetected_ButBackground_EventNotCaptured() {

        class BackgroundSentryUIApplication: SentryUIApplication {
            override var applicationState: UIApplication.State { .background }
        }

        givenInitializedTracker()
        setUpThreadInspector()
        SentryDependencyContainer.sharedInstance().application = BackgroundSentryUIApplication()

        Dynamic(sut).anrDetected()

        assertNoEventCaptured()
    }
#endif

    func testDealloc_CallsUninstall() {
        givenInitializedTracker()
        
        // // So ARC deallocates the SentryANRTrackingIntegration
        func initIntegration() {
            self.crashWrapper.internalIsBeingTraced = false
            let sut = SentryANRTrackingIntegration()
            sut.install(with: self.options)
        }
        
        initIntegration()
        
        let tracker = SentryDependencyContainer.sharedInstance().getANRTracker(self.options.appHangTimeoutInterval)
        
        let listeners = Dynamic(tracker).listeners.asObject as? NSHashTable<NSObject>
        
        XCTAssertEqual(1, listeners?.count ?? 2)
    }

    func testEventIsNotANR() {
        expect(Event().isAppHangEvent) == false
    }
    
    private func givenInitializedTracker(isBeingTraced: Bool = false) {
        givenSdkWithHub()
        self.crashWrapper.internalIsBeingTraced = isBeingTraced
        sut = SentryANRTrackingIntegration()
        sut.install(with: self.options)
    }
    
    private func setUpThreadInspector(addThreads: Bool = true) {
        let threadInspector = TestThreadInspector.instance

        if addThreads {
            
            let frame1 = Sentry.Frame()
            frame1.function = "Second_frame_function"
            
            let thread1 = SentryThread(threadId: 0)
            thread1.stacktrace = SentryStacktrace(frames: [frame1], registers: [:])
            thread1.current = true
            
            let frame2 = Sentry.Frame()
            frame2.function = "main"
            
            let thread2 = SentryThread(threadId: 1)
            thread2.stacktrace = SentryStacktrace(frames: [frame2], registers: [:])
            thread2.current = false
            
            threadInspector.allThreads = [
                thread2,
                thread1
            ]
        } else {
            threadInspector.allThreads = []
        }
        
        SentrySDK.currentHub().getClient()?.threadInspector = threadInspector
    }
}
