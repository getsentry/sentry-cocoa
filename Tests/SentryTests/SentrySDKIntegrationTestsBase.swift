import Foundation
@testable import Sentry
import SentryTestUtils
import XCTest

// swiftlint:disable test_case_accessibility
// This is a base test class, so we can't keep all methods private.
class SentrySDKIntegrationTestsBase: XCTestCase {
    
    var currentDate = TestCurrentDateProvider()
    var crashWrapper: TestSentryCrashWrapper!
    
    var options: Options {
        Options()
    }
    
    override func setUp() {
        super.setUp()
        crashWrapper = TestSentryCrashWrapper.sharedInstance()
        SentryDependencyContainer.sharedInstance().crashWrapper = crashWrapper
        currentDate = TestCurrentDateProvider()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func givenSdkWithHub(_ options: Options? = nil, scope: Scope = Scope()) {
        let client = TestClient(options: options ?? self.options)
        let hub = SentryHub(client: client, andScope: scope, andCrashWrapper: TestSentryCrashWrapper.sharedInstance(), andDispatchQueue: SentryDispatchQueueWrapper())
        
        SentrySDK.setStart(self.options)
        SentrySDK.setCurrentHub(hub)
    }
    
    func assertNoEventCaptured() {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        XCTAssertEqual(0, client.captureEventInvocations.count, "No event should be captured.")
    }
    
    func assertEventWithScopeCaptured(_ callback: (Event?, Scope?, [SentryEnvelopeItem]?) throws -> Void) throws {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureEventWithScopeInvocations.count, "More than one `Event` captured.")
        let capture = client.captureEventWithScopeInvocations.first
        try callback(capture?.event, capture?.scope, capture?.additionalEnvelopeItems)
    }
    
    func assertCrashEventWithScope(_ callback: (Event?, Scope?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureCrashEventInvocations.count, "Wrong number of `Crashs` captured.")
        let capture = client.captureCrashEventInvocations.first
        callback(capture?.event, capture?.scope)
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        currentDate.setDate(date: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(bySeconds))
    }
}

// swiftlint:enable test_case_accessibility
