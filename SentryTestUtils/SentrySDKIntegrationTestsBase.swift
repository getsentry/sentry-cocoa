import Foundation
import XCTest

open class SentrySDKIntegrationTestsBase: XCTestCase {
    
    public var currentDate = TestCurrentDateProvider()
    public var crashWrapper: TestSentryCrashWrapper!
    
    open var options: Options {
        Options()
    }
    
    open override func setUp() {
        super.setUp()
        crashWrapper = TestSentryCrashWrapper()
        SentryDependencyContainer.sharedInstance().crashWrapper = crashWrapper
        currentDate = TestCurrentDateProvider()
    }
    
    open override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    public func givenSdkWithHub(_ options: Options? = nil, scope: Scope = Scope()) {
        let client = TestClient(options: options ?? self.options)
        let hub = SentryHub(client: client, andScope: scope, andCrashWrapper: TestSentryCrashWrapper(), andCurrentDateProvider: currentDate)
        
        SentrySDK.setCurrentHub(hub)
    }
    
    public func givenSdkWithHubButNoClient() {
        SentrySDK.setCurrentHub(SentryHub(client: nil, andScope: nil))
    }
    
    public func assertNoEventCaptured() {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        XCTAssertEqual(0, client.captureEventInvocations.count, "No event should be captured.")
    }
    
    public func assertEventCaptured(_ callback: (Event?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        XCTAssertEqual(1, client.captureEventInvocations.count, "More than one `Event` captured.")
        callback(client.captureEventInvocations.first)
    }
    
    public func assertEventWithScopeCaptured(_ callback: (Event?, Scope?, [SentryEnvelopeItem]?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureEventWithScopeInvocations.count, "More than one `Event` captured.")
        let capture = client.captureEventWithScopeInvocations.first
        callback(capture?.event, capture?.scope, capture?.additionalEnvelopeItems)
    }
    
    public func lastErrorWithScopeCaptured(_ callback: (Error?, Scope?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureErrorWithScopeInvocations.count, "More than one `Error` captured.")
        let capture = client.captureErrorWithScopeInvocations.first
        callback(capture?.error, capture?.scope)
    }
    
    public func assertExceptionWithScopeCaptured(_ callback: (NSException?, Scope?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureExceptionWithScopeInvocations.count, "More than one `Exception` captured.")
        let capture = client.captureExceptionWithScopeInvocations.first
        callback(capture?.exception, capture?.scope)
    }
    
    public func assertMessageWithScopeCaptured(_ callback: (String?, Scope?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureMessageWithScopeInvocations.count, "More than one `Exception` captured.")
        let capture = client.captureMessageWithScopeInvocations.first
        callback(capture?.message, capture?.scope)
    }
    
    public func assertCrashEventWithScope(_ callback: (Event?, Scope?) -> Void) {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(1, client.captureCrashEventInvocations.count, "Wrong number of `Crashs` captured.")
        let capture = client.captureCrashEventInvocations.first
        callback(capture?.event, capture?.scope)
    }
    
    public func advanceTime(bySeconds: TimeInterval) {
        currentDate.setDate(date: currentDate.date().addingTimeInterval(bySeconds))
    }
}
