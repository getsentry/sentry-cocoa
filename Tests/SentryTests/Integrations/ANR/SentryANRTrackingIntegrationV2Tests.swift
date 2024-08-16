@testable import _SentryPrivate
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryANRTrackingIntegrationV2Tests: SentrySDKIntegrationTestsBase {
    
    private class Fixture {
        let options: Options
        
        let currentDate = TestCurrentDateProvider()
                
        init() {
            options = Options()
            options.enableAppHangTrackingV2 = true
            options.appHangTimeoutInterval = 4.5
        }
    }
    
    private var fixture: Fixture!
    private var sut: SentryANRTrackingIntegrationV2!
    
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
        
        sut = SentryANRTrackingIntegrationV2()
        let result = sut.install(with: options)

        XCTAssertFalse(result)
    }
    
    func test_appHangsTimeoutInterval_Zero() {
        let options = Options()
        options.enableAppHangTracking = true
        options.appHangTimeoutInterval = 0
        
        sut = SentryANRTrackingIntegrationV2()
        let result = sut.install(with: options)
        
        XCTAssertFalse(result)
    }
    
    func testANRDetected_EventCaptured() throws {
        givenInitializedTracker()
        setUpThreadInspector()
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        
        try assertEventWithScopeCaptured { event, _, _ in
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
            XCTAssertEqual(ex.stacktrace?.snapshot?.boolValue, true)
            XCTAssertEqual(try XCTUnwrap(event?.threads?.first).current?.boolValue, true)
            XCTAssertEqual(event?.isAppHangEvent, true)
            
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
    
    func testANRDetected_DetectingPaused_NoEventCaptured() {
        givenInitializedTracker()
        setUpThreadInspector()
        sut.pauseAppHangTracking()
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        
        assertNoEventCaptured()
    }
    
    func testANRDetected_DetectingPausedResumed_EventCaptured() throws {
        givenInitializedTracker()
        setUpThreadInspector()
        sut.pauseAppHangTracking()
        sut.resumeAppHangTracking()
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        
        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNotNil(event)
            guard let ex = event?.exceptions?.first else {
                XCTFail("ANR Exception not found")
                return
            }
            
            XCTAssertEqual(ex.mechanism?.type, "AppHang")
        }
    }
    
    func testCallPauseResumeOnMultipleThreads_DoesNotCrash() {
        givenInitializedTracker()
        
        testConcurrentModifications(asyncWorkItems: 100, writeLoopCount: 10, writeWork: {_ in
            self.sut.pauseAppHangTracking()
            Dynamic(self.sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        }, readWork: {
            self.sut.resumeAppHangTracking()
            Dynamic(self.sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        })
    }
    
    func testANRDetected_ButNoThreads_EventNotCaptured() {
        givenInitializedTracker()
        setUpThreadInspector(addThreads: false)
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        
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

        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)

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
        
        let tracker = SentryDependencyContainer.sharedInstance().getANRTrackerV2(self.options.appHangTimeoutInterval)
        
        let listeners = Dynamic(tracker).listeners.asObject as? NSHashTable<NSObject>
        
        XCTAssertEqual(1, listeners?.count ?? 2)
    }

    func testEventIsNotANR() {
        XCTAssertFalse(Event().isAppHangEvent)
    }
    
    private func givenInitializedTracker(isBeingTraced: Bool = false) {
        givenSdkWithHub()
        self.crashWrapper.internalIsBeingTraced = isBeingTraced
        sut = SentryANRTrackingIntegrationV2()
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

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
