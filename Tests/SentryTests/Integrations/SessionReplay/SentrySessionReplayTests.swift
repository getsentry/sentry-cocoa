import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
#if canImport(UIKit)
import UIKit
#endif
import XCTest

#if os(iOS) || os(tvOS)
class SentrySessionReplayTests: XCTestCase {
    
    private class ScreenshotProvider: NSObject, SentryViewScreenshotProvider {
        var lastImageCall: UIView?
        var imageCallCount = 0
        var beforeComplete: (() -> Void)?

        func image(view: UIView, onComplete: @escaping Sentry.ScreenshotCallback) {
            lastImageCall = view
            imageCallCount += 1
            beforeComplete?()
            onComplete(UIImage.add)
        }
    }

    private class DraggingScrollView: UIScrollView {
        override var isDragging: Bool { true }
    }
     
    private class TestTouchTracker: SentryTouchTracker {
        var replayEventsCallback: ((Date, Date) -> Void)?
        
        override func replayEvents(from: Date, until: Date) -> [SentryRRWebEvent] {
            replayEventsCallback?(from, until)
            return super.replayEvents(from: from, until: until)
        }
    }
    
    private class TestReplayMaker: NSObject, SentryReplayVideoMaker {
        var screens = [String]()
        
        var createVideoCallBack: ((SentryVideoInfo) -> Void)?
        var overrideBeginning: Date?
        
        struct CreateVideoCall {
            var beginning: Date
            var end: Date
        }
        
        var lastCallToCreateVideo: CreateVideoCall?
        func createVideoInBackgroundWith(
            beginning: Date,
            end: Date,
            completion: @escaping ([Sentry.SentryVideoInfo]) -> Void
        ) {
            // Note: This implementation is just to satisfy the protocol.
            // If possible, keep the tests logic the synchronous version `createVideoWith`
            let videos = createVideoWith(beginning: beginning, end: end)
            completion(videos)
        }

        func createVideoWith(beginning: Date, end: Date) -> [Sentry.SentryVideoInfo] {
            lastCallToCreateVideo = CreateVideoCall(beginning: beginning, end: end)
            let outputFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempvideo.mp4")
            
            XCTAssertNoThrow(try "Video Data".write(to: outputFileURL, atomically: true, encoding: .utf8))
            let videoInfo = SentryVideoInfo(path: outputFileURL, height: 1_024, width: 480, duration: end.timeIntervalSince(overrideBeginning ?? beginning), frameCount: 5, frameRate: 1, start: overrideBeginning ?? beginning, end: end, fileSize: 10, screens: screens)
            
            createVideoCallBack?(videoInfo)
            return [videoInfo]
        }

        var lastFrameTimestamp: Date?
        var lastFrame: UIImage?
        func addFrameAsync(timestamp: Date, maskedViewImage: UIImage, forScreen: String?) {
            lastFrameTimestamp = timestamp
            lastFrame = maskedViewImage
            guard let forScreen = forScreen else { return }
            screens.append(forScreen)
        }
        
        var lastReleaseUntil: Date?
        func releaseFramesUntil(_ date: Date) {
            lastReleaseUntil = date
        }
    }
    
    private class Fixture: NSObject, SentrySessionReplayDelegate {
        let dateProvider = TestCurrentDateProvider()
        let random = TestRandom(value: 0)
        let screenshotProvider = ScreenshotProvider()
        let rootView = UIView()
        let replayMaker = TestReplayMaker()
        let cacheFolder = FileManager.default.temporaryDirectory

        var breadcrumbs: [Breadcrumb]?
        var isFullSession = true
        var lastReplayEvent: SentryReplayEvent?
        var lastReplayRecording: SentryReplayRecording?
        var lastVideoUrl: URL?
        var lastReplayId: SentryId?
        var currentScreen: String?
        var sessionReplayEndedInvocations = Invocations<Void>()

        func getSut(
            options: SentryReplayOptions = .init(sessionSampleRate: 0, onErrorSampleRate: 0),
            touchTracker: SentryTouchTracker? = nil
        ) -> SentrySessionReplay {
            return SentrySessionReplay(
                replayOptions: options,
                replayFolderPath: cacheFolder,
                screenshotProvider: screenshotProvider,
                replayMaker: replayMaker,
                breadcrumbConverter: SentrySRDefaultBreadcrumbConverter(),
                touchTracker: touchTracker ?? SentryTouchTracker(dateProvider: dateProvider, scale: 0),
                dateProvider: dateProvider,
                delegate: self
            )
        }
        
        func sessionReplayShouldCaptureReplayForError() -> Bool {
            return isFullSession
        }
        
        func sessionReplayNewSegment(replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, videoUrl: URL) {
            lastReplayEvent = replayEvent
            lastReplayRecording = replayRecording
            lastVideoUrl = videoUrl
        }
        
        func sessionReplayStarted(replayId: SentryId) {
            lastReplayId = replayId
        }

        func sessionReplayEnded() {
            sessionReplayEndedInvocations.record(Void())
        }
        
        func breadcrumbsForSessionReplay() -> [Breadcrumb] {
            breadcrumbs ?? []
        }
        
        func currentScreenNameForSessionReplay() -> String? {
            return currentScreen
        }
    }
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
        
    func testDontSentReplay_NoFullSession() {
        let fixture = Fixture()
        let sut = fixture.getSut()
        sut.start(rootView: fixture.rootView, fullSession: false)
        
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        
        XCTAssertNil(fixture.lastReplayEvent)
    }

    func testStart_StartsCaptureScheduler() {
        // -- Arrange --
        let fixture = Fixture()
        let sut = fixture.getSut()

        // -- Act --
        sut.start(rootView: fixture.rootView, fullSession: false)

        // -- Assert --
        XCTAssertTrue(sut.isRunning)
    }
    
    func testSentReplay_FullSession() {
        let fixture = Fixture()
        
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)
        XCTAssertEqual(fixture.lastReplayId, sut.sessionReplayId)
        
        fixture.dateProvider.advance(by: 1)
        
        let startEvent = fixture.dateProvider.date()
        
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        
        guard let videoArguments = fixture.replayMaker.lastCallToCreateVideo else {
            XCTFail("Replay maker create video was not called")
            return
        }
        
        XCTAssertEqual(videoArguments.end, startEvent.addingTimeInterval(5))
        XCTAssertEqual(videoArguments.beginning, startEvent)
        
        XCTAssertNotNil(fixture.lastReplayRecording)
        assertFullSession(sut, expected: true)
    }
   
    func testReplayScreenNames() throws {
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        for i in 1...6 {
            fixture.currentScreen = "Screen \(i)"
            fixture.dateProvider.advance(by: 1)
            Dynamic(sut).newFrame(nil)
        }
                
        let urls = try XCTUnwrap(fixture.lastReplayEvent?.urls)
        
        guard urls.count == 6 else {
        	XCTFail("Expected 6 screen names")
        	return
        }
        XCTAssertEqual(urls[0], "Screen 1")
        XCTAssertEqual(urls[1], "Screen 2")
        XCTAssertEqual(urls[2], "Screen 3")
    }
    
    func testDontSentReplay_NotFullSession() {
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)
        
        XCTAssertNil(fixture.lastReplayId)
        
        fixture.dateProvider.advance(by: 1)
        
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        
        let videoArguments = fixture.replayMaker.lastCallToCreateVideo
        
        XCTAssertNil(videoArguments)
        assertFullSession(sut, expected: false)
    }
    
    func testChangeReplayMode_forErrorEvent() {
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)
        XCTAssertNil(fixture.lastReplayId)
        let event = Event(error: NSError(domain: "Some error", code: 1))
        
        sut.captureReplayFor(event: event)
        XCTAssertEqual(fixture.lastReplayId, sut.sessionReplayId)
        XCTAssertEqual(event.context?["replay"]?["replay_id"] as? String, sut.sessionReplayId?.sentryIdString)
        assertFullSession(sut, expected: true)
    }

    func testChangeReplayMode_forErrorEvent_shouldKeepBufferReplayTypeForFollowingSegments() throws {
        // -- Arrange --
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 0, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)

        // -- Act --
        let event = Event(error: NSError(domain: "Some error", code: 1))
        sut.captureReplayFor(event: event)
        let firstSegment = try XCTUnwrap(fixture.lastReplayEvent)

        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        let secondSegment = try XCTUnwrap(fixture.lastReplayEvent)

        // -- Assert --
        XCTAssertEqual(firstSegment.replayType, .buffer)
        XCTAssertEqual(firstSegment.segmentId, 0)
        XCTAssertEqual(secondSegment.replayType, .buffer)
        XCTAssertEqual(secondSegment.segmentId, 1)
    }
    
    func testDontChangeReplayMode_forNonErrorEvent() {
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)
        
        let event = Event(level: .info)
        
        sut.captureReplayFor(event: event)
        
        assertFullSession(sut, expected: false)
    }
    
    func testChangeReplayMode_forHybridSDKEvent() {
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)

        _ = sut.captureReplay()

        XCTAssertEqual(fixture.lastReplayId, sut.sessionReplayId)
        assertFullSession(sut, expected: true)
    }

    func testCaptureReplay_whenRequestedAsSession_shouldKeepSessionReplayTypeForFollowingSegments() throws {
        // -- Arrange --
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 0, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)

        // -- Act --
        _ = sut.captureReplay(replayType: .session)
        let firstSegment = try XCTUnwrap(fixture.lastReplayEvent)

        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        let secondSegment = try XCTUnwrap(fixture.lastReplayEvent)

        // -- Assert --
        XCTAssertEqual(firstSegment.replayType, .session)
        XCTAssertEqual(firstSegment.segmentId, 0)
        XCTAssertEqual(secondSegment.replayType, .session)
        XCTAssertEqual(secondSegment.segmentId, 1)
    }

    func testSessionReplayMaximumDuration() {
        // -- Arrange --
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)

        // -- Act --
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        XCTAssertTrue(sut.isRunning)
        fixture.dateProvider.advance(by: 3_600)
        Dynamic(sut).newFrame(nil)

        // -- Assert --
        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(fixture.sessionReplayEndedInvocations.count, 1)
    }

    func testSessionReplayMaximumDuration_whenNotReached_shouldNotCallEnded() {
        // -- Arrange --
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)

        // -- Act --
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)

        // -- Assert --
        XCTAssertTrue(sut.isRunning)
        XCTAssertEqual(fixture.sessionReplayEndedInvocations.count, 0)
    }
    
    func testSdkInfoIsSet() throws {
        let fixture = Fixture()
        let options = SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1)
        options.sdkInfo = ["version": "6.0.1", "name": "sentry.test"]
        
        let sut = fixture.getSut(options: options)
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        
        let event = try XCTUnwrap(fixture.lastReplayEvent)
        
        XCTAssertEqual(event.sdk?["version"] as? String, "6.0.1")
        XCTAssertEqual(event.sdk?["name"] as? String, "sentry.test")
    }
    
    func testSaveScreenShotInBufferMode() {
        let fixture = Fixture()
        
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 0, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall)
    }
    
    func testPauseResume_FullSession() {
        let fixture = Fixture()
        
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall)
        sut.pauseSessionMode()
        fixture.screenshotProvider.lastImageCall = nil
        
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        XCTAssertNil(fixture.screenshotProvider.lastImageCall)
        
        fixture.dateProvider.advance(by: 4)
        Dynamic(sut).newFrame(nil)
        XCTAssertNil(fixture.replayMaker.lastCallToCreateVideo)
        
        sut.resume()
        
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall)
        
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        XCTAssertNotNil(fixture.replayMaker.lastCallToCreateVideo)
    }
    
    func testPause_BufferSession() {
        let fixture = Fixture()
        
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 0, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)
        
        fixture.dateProvider.advance(by: 1)
        
        Dynamic(sut).newFrame(nil)
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall)
        sut.pauseSessionMode()
        fixture.screenshotProvider.lastImageCall = nil
        
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall)
        
        fixture.dateProvider.advance(by: 4)
        Dynamic(sut).newFrame(nil)
        
        let event = Event(error: NSError(domain: "Some error", code: 1))
        sut.captureReplayFor(event: event)
        
        XCTAssertNotNil(fixture.replayMaker.lastCallToCreateVideo)
        
        //After changing to session mode the replay should pause
        fixture.screenshotProvider.lastImageCall = nil
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        XCTAssertNil(fixture.screenshotProvider.lastImageCall)
    }
    
    func testFilterCloseNavigationBreadcrumbs() {
        let fixture = Fixture()
        
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)
        XCTAssertEqual(fixture.lastReplayId, sut.sessionReplayId)
        
        fixture.dateProvider.advance(by: 1)
        let startEvent = fixture.dateProvider.date()
                 
        fixture.breadcrumbs = [
            .navigation(screen: "Some Screen", date: startEvent.addingTimeInterval(0.1)), // This should not filter out
            .custom(date: startEvent.addingTimeInterval(0.11)), // This should not filter out
            .navigation(screen: "Child VC 1", date: startEvent.addingTimeInterval(0.11)), // Dont keep this one
            .navigation(screen: "Child VC 2", date: startEvent.addingTimeInterval(0.12)), // Dont keep this one
            .navigation(screen: "Child VC 3", date: startEvent.addingTimeInterval(0.15)), // Dont keep this one
            .navigation(screen: "Another Screen", date: startEvent.addingTimeInterval(0.16)) // This should not filter out
        ]
                
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        
        let event = Event(error: NSError(domain: "Some error", code: 1))
        sut.captureReplayFor(event: event)
        
        let breadCrumbRREvents = fixture.lastReplayRecording?.events.compactMap({ $0 as? SentryRRWebBreadcrumbEvent }) ?? []
        
        XCTAssertEqual(breadCrumbRREvents.count, 3)
        XCTAssertEqual((breadCrumbRREvents[0].data?["payload"] as? [String: Any])?["message"] as? String, "Some Screen")
        XCTAssertEqual((breadCrumbRREvents[1].data?["payload"] as? [String: Any])?["category"] as? String, "custom")
        XCTAssertEqual((breadCrumbRREvents[2].data?["payload"] as? [String: Any])?["message"] as? String, "Another Screen")
    }
  
    func testCaptureAllTouches() {
        let fixture = Fixture()
        let touchTracker = TestTouchTracker(dateProvider: fixture.dateProvider, scale: 1)
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1), touchTracker: touchTracker)
        sut.start(rootView: fixture.rootView, fullSession: true)

        //Starting session replay at time 0
        Dynamic(sut).newFrame(nil)
        
        //Advancing one second and capturing another frame
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        
        //Advancing 5 more second to complete one segment
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        
        let endOfFirstSegment = fixture.dateProvider.date()
        
        //Advancing 2 seconds to start another segment at second 7
        //This means session replay didnt capture screens between seconds 5 and 7
        fixture.dateProvider.advance(by: 2)
        Dynamic(sut).newFrame(nil)
        
        let expect = expectation(description: "Touch Tracker called")
        touchTracker.replayEventsCallback = { begin, end in
            // Even though the second segment started at second 7,
            // we should capture all touch events since the end of the first segment.
            
            XCTAssertEqual(begin, endOfFirstSegment)
            XCTAssertEqual(end, fixture.dateProvider.date())
            expect.fulfill()
        }
        
        // This will make the mock videoInfo starts at second 7 as well
        fixture.replayMaker.overrideBeginning = Date(timeIntervalSinceReferenceDate: 7)
        
        //Advancing another 5 seconds to close the second segment
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        
        wait(for: [expect], timeout: 1)
    }
    
    func testOptionsInTheEventAllEnabled() throws {
        let fixture = Fixture()
        
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)

        let breadCrumbRREvents = fixture.lastReplayRecording?.events.compactMap({ $0 as? SentryRRWebOptionsEvent }) ?? []
        XCTAssertEqual(breadCrumbRREvents.count, 1)
        
        let options = try XCTUnwrap(breadCrumbRREvents.first?.data?["payload"] as? [String: Any])
        
        XCTAssertEqual(options["sessionSampleRate"] as? Float, 1)
        XCTAssertEqual(options["errorSampleRate"] as? Float, 1)
        XCTAssertEqual(options["maskAllText"] as? Bool, true)
        XCTAssertEqual(options["maskAllImages"] as? Bool, true)
        XCTAssertNil(options["maskedViewClasses"])
        XCTAssertNil(options["unmaskedViewClasses"])
        XCTAssertEqual(options["quality"] as? String, "medium")
        XCTAssertEqual(options["nativeSdkName"] as? String, SentryMeta.sdkName)
        XCTAssertEqual(options["nativeSdkVersion"] as? String, SentryMeta.versionString)
    }
    
    func testOptionsInTheEventAllChanged() throws {
        let fixture = Fixture()
        
        let replayOptions = SentryReplayOptions(sessionSampleRate: 0, onErrorSampleRate: 0, maskAllText: false, maskAllImages: false)
        replayOptions.maskedViewClasses = [UIView.self]
        replayOptions.unmaskedViewClasses = [UITextField.self, UITextView.self]
        replayOptions.quality = .high
        
        let sut = fixture.getSut(options: replayOptions)
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)

        let breadCrumbRREvents = fixture.lastReplayRecording?.events.compactMap({ $0 as? SentryRRWebOptionsEvent }) ?? []
        XCTAssertEqual(breadCrumbRREvents.count, 1)
        
        let options = try XCTUnwrap(breadCrumbRREvents.first?.data?["payload"] as? [String: Any])
        
        XCTAssertEqual(options["sessionSampleRate"] as? Float, 0)
        XCTAssertEqual(options["errorSampleRate"] as? Float, 0)
        XCTAssertEqual(options["maskAllText"] as? Bool, false)
        XCTAssertEqual(options["maskAllImages"] as? Bool, false)
        XCTAssertEqual(options["maskedViewClasses"] as? String, "UIView")
        XCTAssertEqual(options["unmaskedViewClasses"] as? String, "UITextField, UITextView")
        XCTAssertEqual(options["quality"] as? String, "high")
    }
    
    func testCustomOptionsInTheEvent() throws {
        let fixture = Fixture()
        
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)
        sut.replayTags = ["SomeOption": "SomeValue", "AnotherOption": "AnotherValue"]
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)

        let breadCrumbRREvents = fixture.lastReplayRecording?.events.compactMap({ $0 as? SentryRRWebOptionsEvent }) ?? []
        XCTAssertEqual(breadCrumbRREvents.count, 1)
        
        let options = try XCTUnwrap(breadCrumbRREvents.first?.data?["payload"] as? [String: Any])
        
        XCTAssertEqual(options["SomeOption"] as? String, "SomeValue")
        XCTAssertEqual(options["AnotherOption"] as? String, "AnotherValue")
    }
    
    func testOptionsNotInSegmentsOtherThanZero() throws {
        let fixture = Fixture()
        
        let replayOptions = SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1)
        
        let sut = fixture.getSut(options: replayOptions)
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        // First Segment
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        
        // Second Segment
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        
        let breadCrumbRREvents = fixture.lastReplayRecording?.events.compactMap({ $0 as? SentryRRWebOptionsEvent }) ?? []
        XCTAssertEqual(breadCrumbRREvents.count, 0)
    }
    
    func testShouldEnableSessionReplay_withUnreliableEnvironment_withoutOverrideOptionEnabled_shouldNotStart() {
        // -- Arrange --
        let environmentChecker = TestSessionReplayEnvironmentChecker(mockedIsReliableReturnValue: false)
        let experimentalOptions = SentryExperimentalOptions()
        experimentalOptions.enableSessionReplayInUnreliableEnvironment = false

        // -- Assert --
        // Verify that session replay will not actually start
        // (it should have been blocked by isInUnreliableEnvironment)
        XCTAssertFalse(SentrySessionReplay.shouldEnableSessionReplay(environmentChecker: environmentChecker, experimentalOptions: experimentalOptions))
    }

    func testShouldEnableSessionReplay_withUnreliableEnvironment_withOverrideOptionEnabled_shouldStart() {
        // -- Arrange --
        let environmentChecker = TestSessionReplayEnvironmentChecker(mockedIsReliableReturnValue: false)
        let experimentalOptions = SentryExperimentalOptions()
        experimentalOptions.enableSessionReplayInUnreliableEnvironment = true

        // -- Assert --
        // Verify that session replay will start despite unreliable environment
        // (override option is enabled)
        XCTAssertTrue(SentrySessionReplay.shouldEnableSessionReplay(environmentChecker: environmentChecker, experimentalOptions: experimentalOptions))
    }

    // MARK: - Frame Rate Tests

    func testFrameRate_1FPS_takesScreenshotsAtCorrectInterval() {
        // Arrange
        let fixture = Fixture()
        let options = SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1)
        options.frameRate = 1
        let sut = fixture.getSut(options: options)
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        fixture.screenshotProvider.lastImageCall = nil
        
        // Act & Assert - advance by 0.9 seconds, screenshot should NOT be taken
        fixture.dateProvider.advance(by: 0.9)
        Dynamic(sut).newFrame(nil)
        XCTAssertNil(fixture.screenshotProvider.lastImageCall, "Screenshot should not be taken before 1 second interval")
        
        // Act & Assert - advance to exactly 1.0 seconds, screenshot SHOULD be taken
        fixture.dateProvider.advance(by: 0.1)
        Dynamic(sut).newFrame(nil)
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall, "Screenshot should be taken at 1 second interval for 1 FPS")
    }

    func testFrameRate_2FPS_takesScreenshotsAtCorrectInterval() {
        // Arrange
        let fixture = Fixture()
        let options = SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1)
        options.frameRate = 2
        let sut = fixture.getSut(options: options)
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        fixture.screenshotProvider.lastImageCall = nil
        
        // Act & Assert - advance by 0.4 seconds, screenshot should NOT be taken
        fixture.dateProvider.advance(by: 0.4)
        Dynamic(sut).newFrame(nil)
        XCTAssertNil(fixture.screenshotProvider.lastImageCall, "Screenshot should not be taken before 0.5 second interval")
        
        // Act & Assert - advance to 0.5 seconds, screenshot SHOULD be taken
        fixture.dateProvider.advance(by: 0.1)
        Dynamic(sut).newFrame(nil)
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall, "Screenshot should be taken at 0.5 second interval for 2 FPS")
        
        // Act & Assert - reset and test second screenshot
        fixture.screenshotProvider.lastImageCall = nil
        fixture.dateProvider.advance(by: 0.4)
        Dynamic(sut).newFrame(nil)
        XCTAssertNil(fixture.screenshotProvider.lastImageCall, "Screenshot should not be taken before another 0.5 seconds")
        
        fixture.dateProvider.advance(by: 0.1)
        Dynamic(sut).newFrame(nil)
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall, "Screenshot should be taken at next 0.5 second interval")
    }

    func testFrameRate_10FPS_takesScreenshotsAtCorrectInterval() {
        // Arrange
        let fixture = Fixture()
        let options = SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1)
        options.frameRate = 10
        let sut = fixture.getSut(options: options)
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        // Expected interval: 1.0 / 10.0 = 0.1 seconds
        // Take first screenshot to establish baseline
        fixture.dateProvider.advance(by: 0.1)
        Dynamic(sut).newFrame(nil)
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall, "First screenshot should be taken")
        
        fixture.screenshotProvider.lastImageCall = nil
        
        // Act & Assert - advance by 0.09 seconds, screenshot should NOT be taken
        fixture.dateProvider.advance(by: 0.09)
        Dynamic(sut).newFrame(nil)
        XCTAssertNil(fixture.screenshotProvider.lastImageCall, "Screenshot should not be taken before 0.1 second interval")
        
        // Act & Assert - advance to reach 0.1 second interval, screenshot SHOULD be taken
        fixture.dateProvider.advance(by: 0.01)
        Dynamic(sut).newFrame(nil)
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall, "Screenshot should be taken at 0.1 second interval for 10 FPS")
    }

    func testFrameRate_multipleScreenshots_respectsInterval() {
        // Arrange
        let fixture = Fixture()
        let options = SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1)
        options.frameRate = 5
        let sut = fixture.getSut(options: options)
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        // Expected interval: 1.0 / 5.0 = 0.2 seconds
        var screenshotCount = 0
        
        // Act & Assert - take 5 screenshots over 1 second
        // Each screenshot resets the timer, so we need to advance by the full interval each time
        for i in 0..<5 {
            // Advance by full interval
            fixture.dateProvider.advance(by: 0.2)
            Dynamic(sut).newFrame(nil)
            
            XCTAssertNotNil(fixture.screenshotProvider.lastImageCall, "Screenshot #\(i + 1) should be taken at \(Double(i + 1) * 0.2) seconds")
            screenshotCount += 1
            fixture.screenshotProvider.lastImageCall = nil
            
            // Advance by less than interval and verify no screenshot
            if i < 4 { // Don't test after the last screenshot
                fixture.dateProvider.advance(by: 0.1)
                Dynamic(sut).newFrame(nil)
                XCTAssertNil(fixture.screenshotProvider.lastImageCall, "No screenshot should be taken at \(Double(i + 1) * 0.2 + 0.1) seconds")
            }
        }
        
        XCTAssertEqual(screenshotCount, 5, "Should have taken exactly 5 screenshots in 1 second for 5 FPS")
    }

    func testNewFrame_whenScreenshotCaptureIsSlow_shouldBackOffCaptureInterval() {
        // -- Arrange --
        let fixture = Fixture()
        let options = SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1)
        options.frameRate = 1
        fixture.screenshotProvider.beforeComplete = {
            fixture.dateProvider.advance(by: 0.06)
        }
        let sut = fixture.getSut(options: options)
        sut.start(rootView: fixture.rootView, fullSession: true)

        // -- Act --
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        let capturesAfterSlowFrame = fixture.screenshotProvider.imageCallCount
        fixture.screenshotProvider.beforeComplete = nil

        fixture.dateProvider.advance(by: 1.99)
        Dynamic(sut).newFrame(nil)
        let capturesBeforeBackoffExpires = fixture.screenshotProvider.imageCallCount

        fixture.dateProvider.advance(by: 3.1)
        Dynamic(sut).newFrame(nil)

        // -- Assert --
        XCTAssertEqual(capturesAfterSlowFrame, 1)
        XCTAssertEqual(capturesBeforeBackoffExpires, 1)
        XCTAssertEqual(fixture.screenshotProvider.imageCallCount, 2)
    }

    func testNewFrame_whenScrollViewIsDragging_shouldDeferScreenshotTemporarily() {
        // -- Arrange --
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        let scrollView = DraggingScrollView(frame: fixture.rootView.bounds)
        fixture.rootView.addSubview(scrollView)
        sut.start(rootView: fixture.rootView, fullSession: true)

        // -- Act --
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)

        // -- Assert --
        XCTAssertEqual(fixture.screenshotProvider.imageCallCount, 0)

        fixture.dateProvider.advance(by: 1.01)
        Dynamic(sut).newFrame(nil)

        XCTAssertEqual(fixture.screenshotProvider.imageCallCount, 1)
    }

    func testNewFrame_whenViewHasManyActiveAnimations_shouldDeferScreenshotTemporarily() {
        // -- Arrange --
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)

        for index in 0..<4 {
            let animatedView = UIView(frame: CGRect(x: index, y: index, width: 1, height: 1))
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0
            animation.toValue = 1
            animation.duration = 1
            animatedView.layer.add(animation, forKey: "opacity")
            fixture.rootView.addSubview(animatedView)
        }

        // -- Act --
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)

        // -- Assert --
        XCTAssertEqual(fixture.screenshotProvider.imageCallCount, 0)

        fixture.dateProvider.advance(by: 1.01)
        Dynamic(sut).newFrame(nil)

        XCTAssertEqual(fixture.screenshotProvider.imageCallCount, 1)
    }

    // MARK: - Helpers

    private func assertFullSession(_ sessionReplay: SentrySessionReplay, expected: Bool) {
        XCTAssertEqual(sessionReplay.isFullSession, expected)
    }
}

#endif
