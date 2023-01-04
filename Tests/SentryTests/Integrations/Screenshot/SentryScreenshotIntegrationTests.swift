import Sentry
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
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
        SentrySDK.start { $0.attachScreenshot = false }
        XCTAssertEqual(SentrySDK.currentHub().getClient()?.attachmentProcessors.count, 0)
        XCTAssertFalse(sentrycrash_hasSaveScreenshotCallback())
    }
    
    func test_attachScreenshot_enabled() {
        SentrySDK.start { $0.attachScreenshot = true }
        XCTAssertEqual(SentrySDK.currentHub().getClient()?.attachmentProcessors.count, 1)
        XCTAssertTrue(sentrycrash_hasSaveScreenshotCallback())
    }
    
    func test_uninstall() {
        SentrySDK.start { $0.attachScreenshot = true }
        SentrySDK.close()
        
        XCTAssertNil(SentrySDK.currentHub().getClient()?.attachmentProcessors)
        XCTAssertFalse(sentrycrash_hasSaveScreenshotCallback())
    }
    
    func test_attachScreenShot_withError() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        
        let newAttachmentList = sut.processAttachments([], for: event)
        
        XCTAssertEqual(newAttachmentList?.count, 1)
    }
    
    func test_attachScreenShot_withException() {
        let sut = fixture.getSut()
        let event = Event()
        event.exceptions = [Exception(value: "", type: "")]
        
        let newAttachmentList = sut.processAttachments([], for: event)
        
        XCTAssertEqual(newAttachmentList?.count, 1)
    }
    
    func test_attachScreenShot_withError_keepAttachments() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        
        let attachment = Attachment(data: Data(), filename: "Some Attachment")
        
        let newAttachmentList = sut.processAttachments([attachment], for: event)
        
        XCTAssertEqual(newAttachmentList?.count, 2)
        XCTAssertEqual(newAttachmentList?.first, attachment)
    }
    
    func test_attachScreenShot_withException_keepAttachments() {
        let sut = fixture.getSut()
        let event = Event()
        event.exceptions = [Exception(value: "", type: "")]
        
        let attachment = Attachment(data: Data(), filename: "Some Attachment")
        
        let newAttachmentList = sut.processAttachments([attachment], for: event)
        
        XCTAssertEqual(newAttachmentList?.count, 2)
        XCTAssertEqual(newAttachmentList?.first, attachment)
    }
    
    func test_noScreenshot_attachment() {
        let sut = fixture.getSut()
        let event = Event()
        
        let newAttachmentList = sut.processAttachments([], for: event)
        
        XCTAssertEqual(newAttachmentList?.count, 0)
    }
    
    func test_noScreenShot_CrashEvent() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        event.isCrashEvent = true
        
        let newAttachmentList = sut.processAttachments([], for: event)
        
        XCTAssertEqual(newAttachmentList?.count, 0)
    }
    
    func test_noScreenShot_MetricKitEvent() {
        let sut = fixture.getSut()
        
        let newAttachmentList = sut.processAttachments([], for: TestData.metricKitEvent)
        
        XCTAssertEqual(newAttachmentList?.count, 0)
    }
    
    func test_noScreenshot_keepAttachment() {
        let sut = fixture.getSut()
        let event = Event()
        
        let attachment = Attachment(data: Data(), filename: "Some Attachment")
        
        let newAttachmentList = sut.processAttachments([attachment], for: event)
        
        XCTAssertEqual(newAttachmentList?.count, 1)
        XCTAssertEqual(newAttachmentList?.first, attachment)
    }
    
    func test_Attachments_Info() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        fixture.screenshot.result = [Data(repeating: 0, count: 1), Data(repeating: 0, count: 2), Data(repeating: 0, count: 3)]
        
        let newAttachmentList = sut.processAttachments([], for: event) ?? []
        
        XCTAssertEqual(newAttachmentList.count, 3)
        XCTAssertEqual(newAttachmentList[0].filename, "screenshot.png")
        XCTAssertEqual(newAttachmentList[1].filename, "screenshot-2.png")
        XCTAssertEqual(newAttachmentList[2].filename, "screenshot-3.png")
        
        XCTAssertEqual(newAttachmentList[0].contentType, "image/png")
        XCTAssertEqual(newAttachmentList[1].contentType, "image/png")
        XCTAssertEqual(newAttachmentList[2].contentType, "image/png")
        
        XCTAssertEqual(newAttachmentList[0].data?.count, 1)
        XCTAssertEqual(newAttachmentList[1].data?.count, 2)
        XCTAssertEqual(newAttachmentList[2].data?.count, 3)
        
    }
    
}
#endif
