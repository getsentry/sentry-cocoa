@testable import Sentry
import SentryTestUtils
import XCTest

class SentryANRTrackingIntegrationTests: SentrySDKIntegrationTestsBase {
    
    private static let dsn = TestConstants.dsnAsString(username: "SentryANRTrackingIntegrationTests")
    
    private class Fixture {
        let options: Options
        
        let currentDate = TestCurrentDateProvider()
                
        init() {
            options = Options()
            options.dsn = SentryANRTrackingIntegrationTests.dsn
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
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
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
        
        let tracker = Dynamic(sut).tracker.asAnyObject
        XCTAssertNotNil(tracker)
        XCTAssertTrue(tracker is SentryANRTrackerV1)
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
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func test_enableAppHangTrackingV2_UsesV2Tracker() {
        let options = Options()
        options.enableAppHangTracking = true
        options.enableAppHangTrackingV2 = true
        
        sut = SentryANRTrackingIntegration()
        let result = sut.install(with: options)
        XCTAssertTrue(result)

        let tracker = Dynamic(sut).tracker.asAnyObject
        XCTAssertNotNil(tracker)
        XCTAssertTrue(tracker is SentryANRTrackerV2)
    }
#endif
    
    func testANRDetected_EventCaptured() throws {
        givenInitializedTracker()
        setUpThreadInspector()
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)
        
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
    
    func testANRDetected_FullyBlocking_EventCaptured() throws {
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
            XCTAssertEqual(ex.type, "App Hanging Fully Blocked")
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

    func testANRDetected_NonFullyBlocked_EventCaptured() throws {
        givenInitializedTracker()
        setUpThreadInspector()

        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)

        try assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNotNil(event)
            guard let ex = event?.exceptions?.first else {
                XCTFail("ANR Exception not found")
                return
            }

            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hanging Non Fully Blocked")
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
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testANRDetected_NonFullyBlockedDisabled_EventNotCaptured() throws {
        fixture.options.enableReportNonFullyBlockingAppHangs = false
        givenInitializedTracker()
        setUpThreadInspector()

        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)

        assertNoEventCaptured()
    }
#endif
    
    func testANRDetected_DetectingPaused_NoEventCaptured() {
        givenInitializedTracker()
        setUpThreadInspector()
        sut.pauseAppHangTracking()
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)
        
        assertNoEventCaptured()
    }
    
    func testANRDetected_DetectingPausedResumed_EventCaptured() throws {
        givenInitializedTracker()
        setUpThreadInspector()
        sut.pauseAppHangTracking()
        sut.resumeAppHangTracking()
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)
        
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
            Dynamic(self.sut).anrDetectedWithType(SentryANRType.unknown)
        }, readWork: {
            self.sut.resumeAppHangTracking()
            Dynamic(self.sut).anrDetectedWithType(SentryANRType.unknown)
        })
    }
    
    func testANRDetected_ButNoThreads_EventNotCaptured() {
        givenInitializedTracker()
        setUpThreadInspector(addThreads: false)
        
        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)
        
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

        Dynamic(sut).anrDetectedWithType(SentryANRType.unknown)

        assertNoEventCaptured()
    }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

    func testDealloc_CallsUninstall() throws {
        givenInitializedTracker()
        
        // // So ARC deallocates the SentryANRTrackingIntegration
        func initIntegration() {
            self.crashWrapper.internalIsBeingTraced = false
            let sut = SentryANRTrackingIntegration()
            sut.install(with: self.options)
        }
        
        initIntegration()
        
        let tracker = SentryDependencyContainer.sharedInstance().getANRTracker(self.options.appHangTimeoutInterval)
        
        let listeners = try XCTUnwrap(Dynamic(tracker).listeners.asObject as? NSHashTable<NSObject>)
        
        XCTAssertEqual(1, listeners.count)
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testV2_ANRDetected_DoesNotCaptureEvent() throws {
        // Arrange
        givenInitializedTracker(enableV2: true)
        setUpThreadInspector()
        
        // Act
        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)
        
        // Assert
        assertNoEventCaptured()
    }
    
    func testV2_ANRStopped_DoesCaptureEvent() throws {
        // Arrange
        givenInitializedTracker(enableV2: true)
        setUpThreadInspector()
        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)

        // Act
        let result = SentryANRStoppedResult(minDuration: 1.851, maxDuration: 2.249)
        Dynamic(sut).anrStoppedWithResult(result)

        // Assert
        try assertEventWithScopeCaptured { event, _, _ in
            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.mechanism?.type, "AppHang")
            XCTAssertEqual(ex.type, "App Hanging Fully Blocked")
            XCTAssertEqual(ex.value, "App hanging between 1.9 and 2.2 seconds.")
            XCTAssertNotNil(ex.stacktrace)
            XCTAssertEqual(ex.stacktrace?.frames.first?.function, "main")
            XCTAssertEqual(ex.stacktrace?.snapshot?.boolValue, true)
            XCTAssertEqual(try XCTUnwrap(event?.threads?.first).current?.boolValue, true)
            XCTAssertEqual(event?.isAppHangEvent, true)
            
            let threads = try XCTUnwrap(event?.threads)
            
            // Sometimes during tests its possible to have one thread without frames
            // We just need to make sure we retrieve frame information for at least one other thread than the main thread
            let threadsWithFrames = threads.filter {
                ($0.stacktrace?.frames.count ?? 0) >= 1
            }.count
            
            XCTAssertTrue(threadsWithFrames > 1, "Not enough threads with frames")
        }
    }
    
    func testV2_ANRDetected_StopNotCalled_SendsANROnNextInstall() throws {
        // Arrange
        givenInitializedTracker(enableV2: true)
        setUpThreadInspector()
        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)
        
        // Act
        givenInitializedTracker(enableV2: true)
        
        // Assert
        try assertEventWithScopeCaptured { event, _, _ in
            let ex = try XCTUnwrap(event?.exceptions?.first)
            
            XCTAssertEqual(ex.value, "App hanging for at least 4500 ms.")
        }
    }
    
    func testV2_ANRStopped_DoesDeleteTheAppHangEvent() throws {
        // Arrange
        givenInitializedTracker(enableV2: true)
        setUpThreadInspector()
        Dynamic(sut).anrDetectedWithType(SentryANRType.fullyBlocking)
        let result = SentryANRStoppedResult(minDuration: 1.849, maxDuration: 2.251)
        Dynamic(sut).anrStoppedWithResult(result)

        // Act
        sut.install(with: self.options)
        
        // Assert
        try assertEventWithScopeCaptured { event, _, _ in
            let ex = try XCTUnwrap(event?.exceptions?.first)
            XCTAssertEqual(ex.value, "App hanging between 1.8 and 2.3 seconds.")
        }
    }
    
    func testV2_ANRStopped_ButEventDeleted_DoesNotCaptureEvent() throws {
        // Arrange
        givenInitializedTracker(enableV2: true)
        setUpThreadInspector()
        Dynamic(sut).anrDetectedWithType(SentryANRType.nonFullyBlocking)
        SentrySDK.currentHub().client()?.fileManager.deleteAppHangEvent()

        // Act
        let result = SentryANRStoppedResult(minDuration: 1.8, maxDuration: 2.2)
        Dynamic(sut).anrStoppedWithResult(result)

        // Assert
        assertNoEventCaptured()
    }
    
    func testV2_ANRStoppedWithNilResult_DoesNotCaptureEvent() throws {
        // Arrange
        givenInitializedTracker(enableV2: true)
        setUpThreadInspector()

        // Act
        Dynamic(sut).anrStoppedWithResult(nil)

        // Assert
        assertNoEventCaptured()
    }
#endif //  os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    
    func testV1_ANRStopped_DoesNotCaptureEvent() throws {
        // Arrange
        givenInitializedTracker()
        setUpThreadInspector()

        // Act
        let result = SentryANRStoppedResult(minDuration: 1.8, maxDuration: 2.2)
        Dynamic(sut).anrStoppedWithResult(result)

        // Assert
        assertNoEventCaptured()
    }

    func testEventIsNotANR() {
        XCTAssertFalse(Event().isAppHangEvent)
    }
    
    private func givenInitializedTracker(isBeingTraced: Bool = false, enableV2: Bool = false) {
        givenSdkWithHub()
        self.crashWrapper.internalIsBeingTraced = isBeingTraced
        sut = SentryANRTrackingIntegration()
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        if enableV2 {
            self.options.enableAppHangTrackingV2 = true
        }
#endif //  os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
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
