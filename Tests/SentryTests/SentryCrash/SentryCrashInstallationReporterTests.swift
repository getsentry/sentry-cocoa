@testable import Sentry
import SentryTestUtils
import XCTest

class SentryCrashInstallationReporterTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryCrashInstallationReporterTests")
    
    private var testClient: TestClient!
    private var sut: SentryCrashInstallationReporter!
    
    override func setUp() {
        super.setUp()
        sut = SentryCrashInstallationReporter(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: []), crashWrapper: TestSentryCrashWrapper.sharedInstance(), dispatchQueue: TestSentryDispatchQueueWrapper())
        sut.install(PrivateSentrySDKOnly.options.cacheDirectoryPath)
        // Works only if SentryCrash is installed
        sentrycrash_deleteAllReports()
    }
    
    override func tearDown() {
        super.tearDown()
        sentrycrash_deleteAllReports()
        clearTestState()
    }
    
    func testReportIsSentAndDeleted() throws {
        sdkStarted()
        
        try givenStoredSentryCrashReport(resource: "Resources/crash-report-1")

        sut.sendAllReports { filteredReports, _, _ in
            XCTAssertEqual(1, filteredReports?.count)
        }
        
        assertNoReportsStored()
    }
    
    func testFaultyReportIsNotSentAndDeleted() throws {
        sdkStarted()
        
        try givenStoredSentryCrashReport(resource: "Resources/Crash-faulty-report")

        sut.sendAllReports { filteredReports, _, _ in
            XCTAssertEqual(0, filteredReports?.count)
        }
        
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
    
    private func assertNoReportsStored() {
        XCTAssertEqual(0, sentrycrash_getReportCount())
    }
}
