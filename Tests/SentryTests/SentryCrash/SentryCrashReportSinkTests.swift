import SentryTestUtils
import XCTest

class SentryCrashReportSinkTests: SentrySDKIntegrationTestsBase {
    
    private class Fixture {
        let crashWrapper = TestSentryCrashWrapper.sharedInstance()
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        
        var sut: SentryCrashReportSink {
            return SentryCrashReportSink(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: []), crashWrapper: crashWrapper, dispatchQueue: dispatchQueue)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        
        givenSdkWithHub()
    }
        
    func testFilterReports_withScreenShots() {
        filterReportWithAttachment()
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testFilterReports_CopyHubScope() {
        SentrySDK.currentHub().scope.setEnvironment("testFilterReports_CopyHubScope")
        
        let expect = expectation(description: "Callback Called")
        
        let report = [String: Any]()
        
        let reportSink = fixture.sut
        reportSink.filterReports([report]) { _, _, _ in
            self.assertCrashEventWithScope { _, scope in
                let data = scope?.serialize()
                XCTAssertEqual(data?["environment"] as? String, "testFilterReports_CopyHubScope")
                expect.fulfill()
            }
        }
                
        wait(for: [expect], timeout: 1)
        
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testAppStartCrash_LowerBound_CallsFlush() {
        fixture.crashWrapper.internalDurationFromCrashStateInitToLastCrash = 0.001
        
        filterReportWithAttachment()
        
        let client = getTestClient()
        XCTAssertEqual(1, client.flushInvocations.count)
        XCTAssertEqual(5, client.flushInvocations.first)
        XCTAssertEqual(0, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testAppStartCrash_UpperBound_CallsFlush() {
        fixture.crashWrapper.internalDurationFromCrashStateInitToLastCrash = 2.0
        
        filterReportWithAttachment()
        
        let client = getTestClient()
        XCTAssertEqual(1, client.flushInvocations.count)
        XCTAssertEqual(5, client.flushInvocations.first)
        XCTAssertEqual(0, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testAppStartCrash_DurationTooSmall_DoesNotCallFlush() {
        fixture.crashWrapper.internalDurationFromCrashStateInitToLastCrash = 0
        
        filterReportWithAttachment()
        
        let client = getTestClient()
        XCTAssertEqual(0, client.flushInvocations.count)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testAppStartCrash_DurationNegative_DoesNotCallFlush() {
        fixture.crashWrapper.internalDurationFromCrashStateInitToLastCrash = -0.001
        
        filterReportWithAttachment()
        
        let client = getTestClient()
        XCTAssertEqual(0, client.flushInvocations.count)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    func testAppStartCrash_DurationTooBig_DoesNotCallFlush() {
        fixture.crashWrapper.internalDurationFromCrashStateInitToLastCrash = 2.00001
        
        filterReportWithAttachment()
        
        let client = getTestClient()
        XCTAssertEqual(0, client.flushInvocations.count)
        XCTAssertEqual(1, fixture.dispatchQueue.dispatchAsyncCalled)
    }
    
    private func filterReportWithAttachment() {
        let report = ["attachments": ["file.png"]]
        fixture.sut.filterReports([report]) { _, _, _ in
            self.assertCrashEventWithScope { _, scope in
                XCTAssertEqual(scope?.attachments.count, 1)
            }
        }
    }
    
    private func getTestClient() -> TestClient {
        let client = SentrySDK.currentHub().getClient() as? TestClient
        
        if client == nil {
            XCTFail("Hub Client is not a `TestClient`")
        }
        
        return client!
    }
}
