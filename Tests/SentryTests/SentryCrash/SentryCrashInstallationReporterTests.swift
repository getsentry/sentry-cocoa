@testable import Sentry
import XCTest

@available(OSX 10.10, *)
class SentryCrashInstallationReporterTests: SentryBaseUnitTest {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryCrashInstallationReporterTests")
    
    private var testClient: TestClient!
    private var sut: SentryCrashInstallationReporter!
    
    override func setUp() {
        super.setUp()
        sut = SentryCrashInstallationReporter(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: []), crashWrapper: TestSentryCrashWrapper.sharedInstance(), dispatchQueue: TestSentryDispatchQueueWrapper())
        sut.install()
    }
    
    func testFaultyReportIsNotSentAndDeleted() throws {
        sdkStarted()
        
        try givenStoredSentryCrashReport(resource: "Resources/Crash-faulty-report")

        sut.sendAllReports()
        
        // We need to wait a bit until SentryCrash is finished processing reports.
        // It is not optimal to block, but we would need to change the internals
        // of SentryCrash a lot to be able to avoid this delay. As we would
        // like to replace SentryCrash anyway it's not worth the effort right now.
        delayNonBlocking()
        
        assertNoEventsSent()
        assertNoReportsStored()
    }
    
    private func sdkStarted() {
        SentrySDK.start { options in
            options.dsn = SentryCrashInstallationReporterTests.dsnAsString
        }
        let options = Options()
        options.dsn = SentryCrashInstallationReporterTests.dsnAsString
        testClient = TestClient(options: options)
        let hub = SentryHub(client: testClient, andScope: nil)
        SentrySDK.setCurrentHub(hub)
    }
    
    private func assertNoEventsSent() {
        XCTAssertEqual(0, testClient.captureEventWithScopeInvocations.count)
    }
    
    private func assertNoReportsStored() {
        XCTAssertEqual(0, sentrycrash_getReportCount())
    }
}
