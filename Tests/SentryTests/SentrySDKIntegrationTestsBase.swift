import Foundation
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
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
        
        SentrySDKInternal.setStart(with: self.options)
        SentrySDKInternal.setCurrentHub(hub)
    }
    
    func assertNoEventCaptured() {
        guard let client = SentrySDKInternal.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        XCTAssertEqual(0, client.captureEventInvocations.count, "No event should be captured.")
    }
    
    func assertEventWithScopeCaptured(_ callback: (Event?, Scope?, [SentryEnvelopeItem]?) throws -> Void) throws {
        guard let client = SentrySDKInternal.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureEventWithScopeInvocations.count, "More than one `Event` captured.")
        let capture = client.captureEventWithScopeInvocations.first
        try callback(capture?.event, capture?.scope, capture?.additionalEnvelopeItems)
    }
    
    func assertFatalEventWithScope(_ callback: (Event?, Scope?) throws -> Void) rethrows {
        guard let client = SentrySDKInternal.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureFatalEventInvocations.count, "Wrong number of `Crashs` captured.")
        let capture = client.captureFatalEventInvocations.first
        try callback(capture?.event, capture?.scope)
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        currentDate.setDate(date: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(bySeconds))
    }
}

// swiftlint:enable test_case_accessibility
