import Sentry
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryViewHierarchyTests: XCTestCase {

    private class Fixture {
        let viewHierarchy: TestSentryViewHierarchy

        init() {
            let testViewHierarchy = TestSentryViewHierarchy()
            testViewHierarchy.result = ["view hierarchy"]
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

    func test_attachViewHierarchy_disabled() {
        SentrySDK.start { $0.attachViewHierarchy = false }
        XCTAssertEqual(SentrySDK.currentHub().getClient()?.attachmentProcessors.count, 0)
    }

    func test_attachViewHierarchy_enabled() {
        SentrySDK.start { $0.attachViewHierarchy = true }
        XCTAssertEqual(SentrySDK.currentHub().getClient()?.attachmentProcessors.count, 1)
    }

    func test_uninstall() {
        SentrySDK.start { $0.attachViewHierarchy = true }
        SentrySDK.close()
        XCTAssertNil(SentrySDK.currentHub().getClient()?.attachmentProcessors)
    }

    func test_attachments() {
        let sut = fixture.getSut()
        let event = Event(error: NSError(domain: "", code: -1))
        fixture.viewHierarchy.result = ["view hierarchy for window zero", "view hierarchy for window one"]

        let newAttachmentList = sut.processAttachments([], for: event) ?? []

        XCTAssertEqual(newAttachmentList.count, 2)
        XCTAssertEqual(newAttachmentList[0].filename, "view-hierarchy-0.txt")
        XCTAssertEqual(newAttachmentList[1].filename, "view-hierarchy-1.txt")

        XCTAssertEqual(newAttachmentList[0].contentType, "application/octet-stream")
        XCTAssertEqual(newAttachmentList[1].contentType, "application/octet-stream")

        XCTAssertEqual(newAttachmentList[0].data?.count, "view hierarchy for window zero".lengthOfBytes(using: .utf8))
        XCTAssertEqual(newAttachmentList[1].data?.count, "view hierarchy for window one".lengthOfBytes(using: .utf8))

    }

}
#endif
