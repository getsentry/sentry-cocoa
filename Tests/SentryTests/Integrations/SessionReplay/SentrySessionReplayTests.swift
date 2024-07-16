import Foundation
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)
class SentrySessionReplayTests: XCTestCase {
    
    private class ScreenshotProvider: NSObject, SentryViewScreenshotProvider {
        var lastImageCall: (view: UIView, options: SentryRedactOptions)?
        func image(view: UIView, options: Sentry.SentryRedactOptions, onComplete: @escaping Sentry.ScreenshotCallback) {
            onComplete(UIImage.add)
            lastImageCall = (view, options)
        }
    }
     
    private class TestReplayMaker: NSObject, SentryReplayVideoMaker {
        var videoWidth: Int = 0
        var videoHeight: Int = 0
         
        var screens = [String]()
        
        struct CreateVideoCall {
            var beginning: Date
            var end: Date
            var outputFileURL: URL
            var completion: ((Sentry.SentryVideoInfo?, Error?) -> Void)
        }
        
        var lastCallToCreateVideo: CreateVideoCall?
        func createVideoWith(beginning: Date, end: Date, outputFileURL: URL, completion: @escaping (Sentry.SentryVideoInfo?, (Error)?) -> Void) throws {
            lastCallToCreateVideo = CreateVideoCall(beginning: beginning,
                                                    end: end,
                                                    outputFileURL: outputFileURL,
                                                    completion: completion)
            
            try? "Video Data".write(to: outputFileURL, atomically: true, encoding: .utf8)
            
            let videoInfo = SentryVideoInfo(path: outputFileURL, height: 1_024, width: 480, duration: end.timeIntervalSince(beginning), frameCount: 5, frameRate: 1, start: beginning, end: end, fileSize: 10, screens: screens)
            
            completion(videoInfo, nil)
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
        
        func getSut(options: SentryReplayOptions = .init(sessionSampleRate: 0, errorSampleRate: 0) ) -> SentrySessionReplay {
            return SentrySessionReplay(replayOptions: options,
                                       replayFolderPath: cacheFolder,
                                       screenshotProvider: screenshotProvider,
                                       replayMaker: replayMaker,
                                       breadcrumbConverter: SentrySRDefaultBreadcrumbConverter(),
                                       touchTracker: SentryTouchTracker(dateProvider: dateProvider, scale: 0),
                                       dateProvider: dateProvider,
                                       delegate: self,
                                       displayLinkWrapper: displayLink)
        }
        
        func sessionReplayIsFullSession() -> Bool {
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
    
    func testVideoSize() {
        let fixture = Fixture()
        let options = SentryReplayOptions(sessionSampleRate: 1, errorSampleRate: 1)
        let sut = fixture.getSut(options: options)
        let view = fixture.rootView
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 900)
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        XCTAssertEqual(Int(320 * options.sizeScale), fixture.replayMaker.videoWidth)
        XCTAssertEqual(Int(900 * options.sizeScale), fixture.replayMaker.videoHeight)
    }
    
    func testSentReplay_FullSession() {
        let fixture = Fixture()
        
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, errorSampleRate: 1))
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
        XCTAssertEqual(videoArguments.outputFileURL, fixture.cacheFolder.appendingPathComponent("segments/0.mp4"))
        
        XCTAssertNotNil(fixture.lastReplayRecording)
        XCTAssertEqual(fixture.lastVideoUrl, videoArguments.outputFileURL)
        assertFullSession(sut, expected: true)
    }
    
    func testReplayScreenNames() throws {
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, errorSampleRate: 1))
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
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, errorSampleRate: 1))
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
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, errorSampleRate: 1))
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
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, errorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)
        
        let event = Event(level: .info)
        
        sut.captureReplayFor(event: event)
        
        assertFullSession(sut, expected: false)
    }
    
    func testChangeReplayMode_forHybridSDKEvent() {
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, errorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)

        _ = sut.captureReplay()

        XCTAssertEqual(fixture.lastReplayId, sut.sessionReplayId)
        assertFullSession(sut, expected: true)
    }

    func testSessionReplayMaximumDuration() {
        let fixture = Fixture()
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, errorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: true)
        
        Dynamic(sut).newFrame(nil)
        fixture.dateProvider.advance(by: 5)
        Dynamic(sut).newFrame(nil)
        XCTAssertTrue(sut.isRunning)
        fixture.dateProvider.advance(by: 3_600)
        Dynamic(sut).newFrame(nil)
        
        XCTAssertFalse(sut.isRunning)
    }
    
    func testSaveScreenShotInBufferMode() {
        let fixture = Fixture()
        
        let sut = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 0, errorSampleRate: 1))
        sut.start(rootView: fixture.rootView, fullSession: false)
        fixture.dateProvider.advance(by: 1)
        Dynamic(sut).newFrame(nil)
        
        XCTAssertNotNil(fixture.screenshotProvider.lastImageCall)
    }
    
    @available(iOS 16.0, tvOS 16, *)
    func testDealloc_CallsStop() {
        let fixture = Fixture()
        func sutIsDeallocatedAfterCallingMe() {
            _ = fixture.getSut(options: SentryReplayOptions(sessionSampleRate: 1, errorSampleRate: 1))
        }
        sutIsDeallocatedAfterCallingMe()
        
        XCTAssertEqual(fixture.displayLink.invalidateInvocations.count, 1)
    }

    func assertFullSession(_ sessionReplay: SentrySessionReplay, expected: Bool) {
        XCTAssertEqual(sessionReplay.isFullSession, expected)
    }
}

#endif
