import Foundation
@testable import Sentry
import SentryTestUtils
import XCTest

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
        
        SentrySDK.setCurrentHub(hub)
    }
    
    func givenSdkWithHubButNoClient() {
        SentrySDK.setCurrentHub(SentryHub(client: nil, andScope: nil))
    }
    
    func assertNoEventCaptured() {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        XCTAssertEqual(0, client.captureEventInvocations.count, "No event should be captured.")
    }
    
    func assertEventCaptured(_ callback: (Event?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        XCTAssertEqual(1, client.captureEventInvocations.count, "More than one `Event` captured.")
        callback(client.captureEventInvocations.first)
    }
    
    func assertEventWithScopeCaptured(_ callback: (Event?, Scope?, [SentryEnvelopeItem]?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureEventWithScopeInvocations.count, "More than one `Event` captured.")
        let capture = client.captureEventWithScopeInvocations.first
        callback(capture?.event, capture?.scope, capture?.additionalEnvelopeItems)
    }
    
    func lastErrorWithScopeCaptured(_ callback: (Error?, Scope?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureErrorWithScopeInvocations.count, "More than one `Error` captured.")
        let capture = client.captureErrorWithScopeInvocations.first
        callback(capture?.error, capture?.scope)
    }
    
    func assertExceptionWithScopeCaptured(_ callback: (NSException?, Scope?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureExceptionWithScopeInvocations.count, "More than one `Exception` captured.")
        let capture = client.captureExceptionWithScopeInvocations.first
        callback(capture?.exception, capture?.scope)
    }
    
    func assertMessageWithScopeCaptured(_ callback: (String?, Scope?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureMessageWithScopeInvocations.count, "More than one `Exception` captured.")
        let capture = client.captureMessageWithScopeInvocations.first
        callback(capture?.message, capture?.scope)
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
    
    func advanceTime(bySeconds: TimeInterval) {
        currentDate.setDate(date: SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(bySeconds))
    }
}
