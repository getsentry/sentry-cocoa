#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import Sentry
import SentryTestUtils
import XCTest

class SentryScreenshotIntegrationTests: XCTestCase {
    
    private class Fixture {
        let screenshot: TestSentryScreenshot
        
        init() {
            let testScreenShot = TestSentryScreenshot()
            testScreenShot.result = [Data(count: 10)]
            screenshot = testScreenShot
        }
        
        func getSut() -> SentryScreenshotIntegration {
            let result = SentryScreenshotIntegration()
            return result
        }
    }

    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()

        SentryDependencyContainer.sharedInstance().screenshot = fixture.screenshot
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func test_attachScreenshot_disabled() {
        SentrySDK.start {
            $0.attachScreenshot = false
            $0.setIntegrations([SentryScreenshotIntegration.self])
        }
        XCTAssertEqual(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors.count, 0)
        XCTAssertFalse(sentrycrash_hasSaveScreenshotCallback())
    }
    
    func test_attachScreenshot_enabled() {
        SentrySDK.start {
            $0.attachScreenshot = true
            $0.setIntegrations([SentryScreenshotIntegration.self])
        }
        XCTAssertEqual(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors.count, 1)
        XCTAssertTrue(sentrycrash_hasSaveScreenshotCallback())
    }
    
    func test_uninstall() {
        SentrySDK.start {
            $0.attachScreenshot = true
            $0.setIntegrations([SentryScreenshotIntegration.self])
        }
        SentrySDK.close()
        
        XCTAssertNil(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors)
        XCTAssertFalse(sentrycrash_hasSaveScreenshotCallback())
    }
    
    func test_attachScreenShot_withError() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        
        let newAttachmentList = sut.processAttachments([], for: event)
        
        XCTAssertEqual(newAttachmentList.count, 1)
    }
    
    func test_attachScreenShot_withException() {
        let sut = fixture.getSut()
        let event = Event()
        event.exceptions = [Exception(value: "", type: "")]
        
        let newAttachmentList = sut.processAttachments([], for: event)
        
        XCTAssertEqual(newAttachmentList.count, 1)
    }
    
    func test_attachScreenShot_withError_keepAttachments() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        
        let attachment = Attachment(data: Data(), filename: "Some Attachment")
        
        let newAttachmentList = sut.processAttachments([attachment], for: event)
        
        XCTAssertEqual(newAttachmentList.count, 2)
        XCTAssertEqual(newAttachmentList.first, attachment)
    }
    
    func test_attachScreenShot_withException_keepAttachments() {
        let sut = fixture.getSut()
        let event = Event()
        event.exceptions = [Exception(value: "", type: "")]
        
        let attachment = Attachment(data: Data(), filename: "Some Attachment")
        
        let newAttachmentList = sut.processAttachments([attachment], for: event)
        
        XCTAssertEqual(newAttachmentList.count, 2)
        XCTAssertEqual(newAttachmentList.first, attachment)
    }
    
    func test_noScreenshot_attachment() {
        let sut = fixture.getSut()
        let event = Event()
        
        let newAttachmentList = sut.processAttachments([], for: event)
        
        XCTAssertEqual(newAttachmentList.count, 0)
    }
    
    func test_noScreenShot_FatalEvent() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        event.isFatalEvent = true
        
        let newAttachmentList = sut.processAttachments([], for: event)
        
        XCTAssertEqual(newAttachmentList.count, 0)
    }

#if os(iOS) || targetEnvironment(macCatalyst)
    func test_noScreenShot_MetricKitEvent() {
        let sut = fixture.getSut()
        
        let newAttachmentList = sut.processAttachments([], for: TestData.metricKitEvent)
        
        XCTAssertEqual(newAttachmentList.count, 0)
    }
#endif // os(iOS) || targetEnvironment(macCatalyst)
    
    func test_NoScreenShot_WhenDiscardedInCallback() {
        let sut = fixture.getSut()
        
        let expectation = expectation(description: "BeforeCaptureScreenshot must be called.")
        
        let options = Options()
        options.beforeCaptureScreenshot = { _ in
            expectation.fulfill()
            return false
        }
        
        sut.install(with: options)
        
        let newAttachmentList = sut.processAttachments([], for: Event(error: NSError(domain: "", code: -1)))
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(newAttachmentList.count, 0)
    }
    
    func test_noScreenshot_keepAttachment() {
        let sut = fixture.getSut()
        let event = Event()
        
        let attachment = Attachment(data: Data(), filename: "Some Attachment")
        
        let newAttachmentList = sut.processAttachments([attachment], for: event)
        
        XCTAssertEqual(newAttachmentList.count, 1)
        XCTAssertEqual(newAttachmentList.first, attachment)
    }
    
    func test_Attachments_Info() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        fixture.screenshot.result = [Data(repeating: 0, count: 1), Data(repeating: 0, count: 2), Data(repeating: 0, count: 3)]
        
        let newAttachmentList = sut.processAttachments([], for: event)
        
        XCTAssertEqual(newAttachmentList.count, 3)
        XCTAssertEqual(try XCTUnwrap(newAttachmentList.first).filename, "screenshot.png")
        XCTAssertEqual(try XCTUnwrap(newAttachmentList.element(at: 1)).filename, "screenshot-2.png")
        XCTAssertEqual(try XCTUnwrap(newAttachmentList.element(at: 2)).filename, "screenshot-3.png")
        
        XCTAssertEqual(try XCTUnwrap(newAttachmentList.first).contentType, "image/png")
        XCTAssertEqual(try XCTUnwrap(newAttachmentList.element(at: 1)).contentType, "image/png")
        XCTAssertEqual(try XCTUnwrap(newAttachmentList.element(at: 2)).contentType, "image/png")
        
        XCTAssertEqual(try XCTUnwrap(newAttachmentList.first).data?.count, 1)
        XCTAssertEqual(try XCTUnwrap(newAttachmentList.element(at: 1)).data?.count, 2)
        XCTAssertEqual(try XCTUnwrap(newAttachmentList.element(at: 2)).data?.count, 3)
        
    }
    
    func test_backgroundForAppHangs() {
        let sut = fixture.getSut()
        let testVH = TestSentryScreenshot()
        SentryDependencyContainer.sharedInstance().screenshot = testVH
        
        let event = Event()
        event.exceptions = [Sentry.Exception(value: "test", type: "App Hanging")]

        let ex = expectation(description: "Attachment Added")
        
        testVH.processScreenshotsCallback = {
            XCTFail("Should not add screenshots to App Hanging events")
        }
        
        DispatchQueue.global().async {
            sut.processAttachments([], for: event)
            ex.fulfill()
        }
        
        wait(for: [ex], timeout: 1)
    }
    
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
