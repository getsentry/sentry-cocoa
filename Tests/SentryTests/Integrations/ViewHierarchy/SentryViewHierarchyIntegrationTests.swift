#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

@_spi(Private) import Sentry
@_spi(Private) import SentryTestUtils
import SentryTestUtils
import XCTest

class SentryViewHierarchyIntegrationTests: XCTestCase {

    private class Fixture {
        let viewHierarchyProvider: TestSentryViewHierarchyProvider
        let defaultOptions: Options

        init() {
            let testViewHierarchy = TestSentryViewHierarchyProvider(dispatchQueueWrapper: TestSentryDispatchQueueWrapper(), applicationProvider: { TestSentryUIApplication() })
            testViewHierarchy.result = Data("view hierarchy".utf8)
            viewHierarchyProvider = testViewHierarchy
            
            defaultOptions = Options()
            defaultOptions.attachViewHierarchy = true
        }

        func getSut(options: Options? = nil) throws -> SentryViewHierarchyIntegration<SentryDependencyContainer> {
            return try XCTUnwrap(SentryViewHierarchyIntegration(with: options ?? defaultOptions, dependencies: SentryDependencyContainer.sharedInstance()))
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

    func test_attachViewHierarchy() {
        SentrySDK.start {
            $0.removeAllIntegrations()
            $0.attachViewHierarchy = false
        }
        XCTAssertEqual(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors.count, 0)
        XCTAssertFalse(sentrycrash_hasSaveViewHierarchyCallback())
    }

    func test_attachViewHierarchy_enabled() {
        SentrySDK.start {
            $0.removeAllIntegrations()
            $0.attachViewHierarchy = true
        }
        XCTAssertEqual(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors.count, 1)
        XCTAssertTrue(sentrycrash_hasSaveViewHierarchyCallback())
    }

    func test_uninstall() {
        SentrySDK.start {
            $0.removeAllIntegrations()
            $0.attachViewHierarchy = true
        }
        SentrySDK.close()
        XCTAssertNil(SentrySDKInternal.currentHub().getClient()?.attachmentProcessors)
        XCTAssertFalse(sentrycrash_hasSaveViewHierarchyCallback())
    }

    func test_integrationAddFileName() {
        SentrySDK.start {
            $0.removeAllIntegrations()
            $0.attachViewHierarchy = true
        }
        saveViewHierarchy("/test/path")
        XCTAssertEqual("/test/path/view-hierarchy.json", fixture.viewHierarchyProvider.saveFilePathUsed)
    }

    func test_processAttachments() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }
        let event = Event(error: NSError(domain: "", code: -1))

        let newAttachmentList = sut.processAttachments([], for: event)

        XCTAssertEqual(newAttachmentList.first?.filename, "view-hierarchy.json")
        XCTAssertEqual(newAttachmentList.first?.contentType, "application/json")
        XCTAssertEqual(newAttachmentList.first?.attachmentType, .viewHierarchy)
    }

    func test_noViewHierarchy_attachment() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }
        let event = Event()

        let newAttachmentList = sut.processAttachments([], for: event)

        XCTAssertEqual(newAttachmentList.count, 0)
    }

    func test_noViewHierarchy_FatalEvent() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }
        let event = Event(error: NSError(domain: "", code: -1))
        event.isFatalEvent = true

        let newAttachmentList = sut.processAttachments([], for: event)

        XCTAssertEqual(newAttachmentList.count, 0)
    }

#if os(iOS) || targetEnvironment(macCatalyst)
    func test_noViewHierarchy_MetricKitEvent() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }
        
        let newAttachmentList = sut.processAttachments([], for: TestData.metricKitEvent)

        XCTAssertEqual(newAttachmentList.count, 0)
    }
#endif // os(iOS) || targetEnvironment(macCatalyst)
    
    func test_noViewHierarchy_WhenDiscardedInCallback() throws {
        let expectation = expectation(description: "BeforeCaptureViewHierarchy must be called.")

        let options = Options()
        options.attachViewHierarchy = true
        options.beforeCaptureViewHierarchy = { _ in
            expectation.fulfill()
            return false
        }

        let sut = try fixture.getSut(options: options)
        defer {
            sut.uninstall()
        }

        let newAttachmentList = sut.processAttachments([], for: Event(error: NSError(domain: "", code: -1)))

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(newAttachmentList.count, 0)
    }

    func test_noViewHierarchy_keepAttachment() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }
        let event = Event()

        let attachment = Attachment(data: Data(), filename: "Some Attachment")

        let newAttachmentList = sut.processAttachments([attachment], for: event)

        XCTAssertEqual(newAttachmentList.count, 1)
        XCTAssertEqual(newAttachmentList.first, attachment)
    }
    
    func test_backgroundForAppHangs() throws {
        let sut = try fixture.getSut()
        defer {
            sut.uninstall()
        }
        let testVH = TestSentryViewHierarchyProvider(dispatchQueueWrapper: TestSentryDispatchQueueWrapper(), applicationProvider: { TestSentryUIApplication() })
        SentryDependencyContainer.sharedInstance().viewHierarchyProvider = testVH

        let event = Event()
        event.exceptions = [Sentry.Exception(value: "test", type: "App Hanging")]
        
        let ex = expectation(description: "Attachment Added")
        
        testVH.appViewHierarchyCallback = {
            XCTFail("Should not add view hierarchy to app hanging events")
        }
        
        let dispatch = DispatchQueue(label: "background")
        dispatch.async {
            sut.processAttachments([], for: event)
            ex.fulfill()
        }
        
        wait(for: [ex], timeout: 1)
    }
    
    func testReportAccessibilityIdentifierTrue() {
        SentrySDK.start {
            $0.removeAllIntegrations()
            $0.attachViewHierarchy = true
        }
        XCTAssertTrue(try XCTUnwrap(SentryDependencyContainer.sharedInstance().viewHierarchyProvider?.reportAccessibilityIdentifier))
    }
    
    func testReportAccessibilityIdentifierFalse() {
        SentrySDK.start {
            $0.removeAllIntegrations()
            $0.attachViewHierarchy = true
            $0.reportAccessibilityIdentifier = false
        }
        XCTAssertFalse(try XCTUnwrap(SentryDependencyContainer.sharedInstance().viewHierarchyProvider?.reportAccessibilityIdentifier))
    }
}

#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
