#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import Sentry
import SentryTestUtils
import XCTest
import Nimble

class SentryViewHierarchyIntegrationTests: XCTestCase {

    private class Fixture {
        let viewHierarchy: TestSentryViewHierarchy

        init() {
            let testViewHierarchy = TestSentryViewHierarchy()
            testViewHierarchy.result = "view hierarchy".data(using: .utf8) ?? Data()
            viewHierarchy = testViewHierarchy
        }

        func getSut() -> SentryViewHierarchyIntegration {
            let result = SentryViewHierarchyIntegration()
            return result
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()

        SentryDependencyContainer.sharedInstance().viewHierarchy = fixture.viewHierarchy
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func test_attachViewHierarchy() {
        SentrySDK.start {
            $0.attachViewHierarchy = false
            $0.setIntegrations([SentryViewHierarchyIntegration.self])
        }
        XCTAssertEqual(SentrySDK.currentHub().getClient()?.attachmentProcessors.count, 0)
        XCTAssertFalse(sentrycrash_hasSaveViewHierarchyCallback())
    }

    func test_attachViewHierarchy_enabled() {
        SentrySDK.start {
            $0.attachViewHierarchy = true
            $0.setIntegrations([SentryViewHierarchyIntegration.self])
        }
        XCTAssertEqual(SentrySDK.currentHub().getClient()?.attachmentProcessors.count, 1)
        XCTAssertTrue(sentrycrash_hasSaveViewHierarchyCallback())
    }

    func test_uninstall() {
        SentrySDK.start {
            $0.attachViewHierarchy = true
            $0.setIntegrations([SentryViewHierarchyIntegration.self])
        }
        SentrySDK.close()
        XCTAssertNil(SentrySDK.currentHub().getClient()?.attachmentProcessors)
        XCTAssertFalse(sentrycrash_hasSaveViewHierarchyCallback())
    }

    func test_integrationAddFileName() {
        SentrySDK.start {
            $0.attachViewHierarchy = true
            $0.setIntegrations([SentryViewHierarchyIntegration.self])
        }
        saveViewHierarchy("/test/path")
        XCTAssertEqual("/test/path/view-hierarchy.json", fixture.viewHierarchy.saveFilePathUsed)
    }

    func test_processAttachments() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))

        let newAttachmentList = sut.processAttachments([], for: event)

        XCTAssertEqual(newAttachmentList?.first?.filename, "view-hierarchy.json")
        XCTAssertEqual(newAttachmentList?.first?.contentType, "application/json")
        XCTAssertEqual(newAttachmentList?.first?.attachmentType, .viewHierarchy)
    }

    func test_noViewHierarchy_attachment() {
        let sut = fixture.getSut()
        let event = Event()

        let newAttachmentList = sut.processAttachments([], for: event)

        XCTAssertEqual(newAttachmentList?.count, 0)
    }

    func test_noViewHierarchy_CrashEvent() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        event.isCrashEvent = true

        let newAttachmentList = sut.processAttachments([], for: event)

        XCTAssertEqual(newAttachmentList?.count, 0)
    }

#if os(iOS) || targetEnvironment(macCatalyst)
    func test_noViewHierarchy_MetricKitEvent() {
        let sut = fixture.getSut()
        
        let newAttachmentList = sut.processAttachments([], for: TestData.metricKitEvent)

        XCTAssertEqual(newAttachmentList?.count, 0)
    }
#endif // os(iOS) || targetEnvironment(macCatalyst)

    func test_noViewHierarchy_keepAttachment() {
        let sut = fixture.getSut()
        let event = Event()

        let attachment = Attachment(data: Data(), filename: "Some Attachment")

        let newAttachmentList = sut.processAttachments([attachment], for: event)

        XCTAssertEqual(newAttachmentList?.count, 1)
        XCTAssertEqual(newAttachmentList?.first, attachment)
    }
    
    func test_backgroundForAppHangs() {
        let sut = fixture.getSut()
        let testVH = TestSentryViewHierarchy()
        SentryDependencyContainer.sharedInstance().viewHierarchy = testVH
        
        let event = Event()
        event.exceptions = [Sentry.Exception(value: "test", type: "App Hanging")]

        var newAttachmentList: [Attachment]?
        
        let ex = expectation(description: "Attachment Added")
        
        testVH.processViewHierarchyCallback = {
            ex.fulfill()
            XCTAssertFalse(Thread.isMainThread)
        }
        
        let dispatch = DispatchQueue(label: "background")
        dispatch.async {
            newAttachmentList = sut.processAttachments([], for: event)
        }
        
        wait(for: [ex], timeout: 1)
        expect(newAttachmentList?.count) == 1
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
