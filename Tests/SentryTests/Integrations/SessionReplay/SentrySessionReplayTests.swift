import Foundation
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)
class SentrySessionReplayTests: XCTestCase {
    
    private class ScreenshotProvider: NSObject, SentryViewScreenshotProvider {
        var lastImageCall: UIView?
        func image(view: UIView, onComplete: @escaping Sentry.ScreenshotCallback) {
            onComplete(UIImage.add)
            lastImageCall = view
        }
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
        func createVideoWith(beginning: Date, end: Date) throws -> [SentryVideoInfo] {
            lastCallToCreateVideo = CreateVideoCall(beginning: beginning, end: end)
            let outputFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tempvideo.mp4")
            
            try? "Video Data".write(to: outputFileURL, atomically: true, encoding: .utf8)
            let videoInfo = SentryVideoInfo(path: outputFileURL, height: 1_024, width: 480, duration: end.timeIntervalSince(overrideBeginning ?? beginning), frameCount: 5, frameRate: 1, start: overrideBeginning ?? beginning, end: end, fileSize: 10, screens: screens)
            
            createVideoCallBack?(videoInfo)
            return [videoInfo]
        }
        
        var lastFrame: UIImage?
        func addFrameAsync(image: UIImage, forScreen: String?) {
            lastFrame = image
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
        let displayLink = TestDisplayLinkWrapper()
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
        
        func getSut(options: SentryReplayOptions = .init(sessionSampleRate: 0, onErrorSampleRate: 0), dispatchQueue: SentryDispatchQueueWrapper = TestSentryDispatchQueueWrapper(), touchTracker: SentryTouchTracker? = nil) -> SentrySessionReplay {
            return SentrySessionReplay(replayOptions: options,
                                       replayFolderPath: cacheFolder,
                                       screenshotProvider: screenshotProvider,
                                       replayMaker: replayMaker,
                                       breadcrumbConverter: SentrySRDefaultBreadcrumbConverter(),
                                       touchTracker: touchTracker ?? SentryTouchTracker(dateProvider: dateProvider, scale: 0),
                                       dateProvider: dateProvider,
                                       delegate: self,
                                       dispatchQueue: dispatchQueue,
                                       displayLinkWrapper: displayLink)
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

    func testSessionReplayMaximumDuration() {
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        XCTAssertTrue(fixture.displayLink.isRunning())
        fixture.dateProvider.advance(by: 3_600)
        Dynamic(sut).newFrame(nil)
        
        XCTAssertFalse(fixture.displayLink.isRunning())
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
        XCTAssertEqual(options["maskedViewClasses"] as? String, "")
        XCTAssertEqual(options["unmaskedViewClasses"] as? String, "")
        XCTAssertEqual(options["quality"] as? String, "medium")
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
    
    @available(iOS 16.0, tvOS 16, *)
    func testDealloc_CallsStop() {
        let fixture = Fixture()
        func sutIsDeallocatedAfterCallingMe() {
            _ = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, onErrorSampleRate: 1))
        }
        sutIsDeallocatedAfterCallingMe()
        
        XCTAssertEqual(fixture.displayLink.invalidateInvocations.count, 1)
    }

    func assertFullSession(_ sessionReplay: SentrySessionReplay, expected: Bool) {
        XCTAssertEqual(sessionReplay.isFullSession, expected)
    }
}

#endif
