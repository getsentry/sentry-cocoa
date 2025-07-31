#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import Sentry
import SentryTestUtils
import XCTest

class SentryViewHierarchyIntegrationTests: XCTestCase {

    private class Fixture {
        let viewHierarchyProvider: TestSentryViewHierarchyProvider

        init() {
            let testViewHierarchy = TestSentryViewHierarchyProvider()
            testViewHierarchy.result = Data("view hierarchy".utf8)
            viewHierarchyProvider = testViewHierarchy
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

        SentryDependencyContainer.sharedInstance().viewHierarchyProvider = fixture.viewHierarchyProvider
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func test_attachViewHierarchy() {
        SentrySDK.start {
            $0.attachViewHierarchy = false
            $0.setIntegrations([SentryViewHierarchyIntegration.self])
        }
        XCTAssertEqual(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors.count, 0)
        XCTAssertFalse(sentrycrash_hasSaveViewHierarchyCallback())
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func test_attachViewHierarchy_enabled() {
        SentrySDK.start {
            $0.attachViewHierarchy = true
            $0.setIntegrations([SentryViewHierarchyIntegration.self])
        }
        XCTAssertEqual(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors.count, 1)
        XCTAssertTrue(sentrycrash_hasSaveViewHierarchyCallback())
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func test_uninstall() {
        SentrySDK.start {
            $0.attachViewHierarchy = true
            $0.setIntegrations([SentryViewHierarchyIntegration.self])
        }
        SentrySDK.close()
        XCTAssertNil(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors)
        XCTAssertFalse(sentrycrash_hasSaveViewHierarchyCallback())
    }

    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func test_integrationAddFileName() {
        SentrySDK.start {
            $0.attachViewHierarchy = true
            $0.setIntegrations([SentryViewHierarchyIntegration.self])
        }
        saveViewHierarchy("/test/path")
        XCTAssertEqual("/test/path/view-hierarchy.json", fixture.viewHierarchyProvider.saveFilePathUsed)
    }

    func test_processAttachments() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))

        let newAttachmentList = sut.processAttachments([], for: event)

        XCTAssertEqual(newAttachmentList.first?.filename, "view-hierarchy.json")
        XCTAssertEqual(newAttachmentList.first?.contentType, "application/json")
        XCTAssertEqual(newAttachmentList.first?.attachmentType, .viewHierarchy)
    }

    func test_noViewHierarchy_attachment() {
        let sut = fixture.getSut()
        let event = Event()

        let newAttachmentList = sut.processAttachments([], for: event)

        XCTAssertEqual(newAttachmentList.count, 0)
    }

    func test_noViewHierarchy_FatalEvent() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        event.isFatalEvent = true

        let newAttachmentList = sut.processAttachments([], for: event)

        XCTAssertEqual(newAttachmentList.count, 0)
    }

#if os(iOS) || targetEnvironment(macCatalyst)
    func test_noViewHierarchy_MetricKitEvent() {
        let sut = fixture.getSut()
        
        let newAttachmentList = sut.processAttachments([], for: TestData.metricKitEvent)

        XCTAssertEqual(newAttachmentList.count, 0)
    }
#endif // os(iOS) || targetEnvironment(macCatalyst)
    
    func test_noViewHierarchy_WhenDiscardedInCallback() {
        let sut = fixture.getSut()

        let expectation = expectation(description: "BeforeCaptureViewHierarchy must be called.")

        let options = Options()
        options.attachViewHierarchy = true
        options.beforeCaptureViewHierarchy = { _ in
            expectation.fulfill()
            return false
        }

        sut.install(with: options)

        let newAttachmentList = sut.processAttachments([], for: Event(error: NSError(domain: "", code: -1)))

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(newAttachmentList.count, 0)
    }

    func test_noViewHierarchy_keepAttachment() {
        let sut = fixture.getSut()
        let event = Event()

        let attachment = Attachment(data: Data(), filename: "Some Attachment")

        let newAttachmentList = sut.processAttachments([attachment], for: event)

        XCTAssertEqual(newAttachmentList.count, 1)
        XCTAssertEqual(newAttachmentList.first, attachment)
    }
    
    func test_backgroundForAppHangs() {
        let sut = fixture.getSut()
        let testVH = TestSentryViewHierarchyProvider()
        SentryDependencyContainer.sharedInstance().viewHierarchyProvider = testVH

        let event = Event()
        event.exceptions = [Sentry.Exception(value: "test", type: "App Hanging")]
        
        let ex = expectation(description: "Attachment Added")
        
        testVH.processViewHierarchyCallback = {
            XCTFail("Should not add view hierarchy to app hanging events")
        }
        
        let dispatch = DispatchQueue(label: "background")
        dispatch.async {
            sut.processAttachments([], for: event)
            ex.fulfill()
        }
        
        wait(for: [ex], timeout: 1)
    }
    
    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testReportAccessibilityIdentifierTrue() {
        SentrySDK.start {
            $0.attachViewHierarchy = true
            $0.setIntegrations([SentryViewHierarchyIntegration.self])
        }
        XCTAssertTrue(SentryDependencyContainer.sharedInstance().viewHierarchyProvider.reportAccessibilityIdentifier)
    }
    
    @available(*, deprecated, message: "This is deprecated because SentryOptions integrations is deprecated")
    func testReportAccessibilityIdentifierFalse() {
        SentrySDK.start {
            $0.attachViewHierarchy = true
            $0.reportAccessibilityIdentifier = false
            $0.setIntegrations([SentryViewHierarchyIntegration.self])
        }
        XCTAssertFalse(SentryDependencyContainer.sharedInstance().viewHierarchyProvider.reportAccessibilityIdentifier)
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
