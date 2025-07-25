@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

class SentryCrashInstallationReporterTests: XCTestCase {
        
    private var sut: SentryCrashInstallationReporter!
    private var testClient: TestClient!
    
    override func tearDown() {
        super.tearDown()
        sentrycrash_deleteAllReports()
        clearTestState()
        sut.uninstall()
    }
    
    func testReportIsSentAndDeleted() throws {
        givenSutWithStartedSDK()
        
        try givenStoredSentryCrashReport(resource: "Resources/crash-report-1")

        sut.sendAllReports { filteredReports, _, _ in
            XCTAssertEqual(filteredReports?.count, 1)
        }
        
        XCTAssertEqual(self.testClient.captureFatalEventInvocations.count, 1)
        XCTAssertEqual(sentrycrash_getReportCount(), 0)
    }
    
    /**
     * Validates that handling a crash report with the removed fields total_storage and free_storage works.
     */
    func testShouldCaptureCrashReportWithLegacyStorageInfo() throws {
        givenSutWithStartedSDK()
        
        try givenStoredSentryCrashReport(resource: "Resources/crash-report-legacy-storage-info")

        sut.sendAllReports { filteredReports, _, _ in
            XCTAssertEqual(filteredReports?.count, 1)
        }
        
        XCTAssertEqual(self.testClient.captureFatalEventInvocations.count, 1)
        XCTAssertEqual(sentrycrash_getReportCount(), 0)
        
        let event = self.testClient.captureFatalEventInvocations.last?.event
        XCTAssertEqual(event?.context?["device"]?["free_storage"] as? Int, 278_914_420_736)
        // total_storage got converted to storage_size
        XCTAssertEqual(event?.context?["device"]?["storage_size"] as? Int, 994_662_584_320)
    }
    
    func testShouldCaptureCrashReportWithoutDeviceContext() throws {
        givenSutWithStartedSDK()
        
        try givenStoredSentryCrashReport(resource: "Resources/crash-report-without-device-context")

        sut.sendAllReports { filteredReports, _, _ in
            XCTAssertEqual(filteredReports?.count, 1)
        }
        
        XCTAssertEqual(self.testClient.captureFatalEventInvocations.count, 1)
        XCTAssertEqual(sentrycrash_getReportCount(), 0)
        
        let event = self.testClient.captureFatalEventInvocations.last?.event
        XCTAssertNil(event?.context?["device"])
        XCTAssertEqual(event?.context?["app"]?["app_name"] as? String, "iOS-Swift")
    }
    
    func testFaultyReportIsNotSentAndDeleted() throws {
        givenSutWithStartedSDK()
        
        try givenStoredSentryCrashReport(resource: "Resources/Crash-faulty-report")

        sut.sendAllReports { filteredReports, _, _ in
            XCTAssertEqual(filteredReports?.count, 0)
        }
        
        XCTAssertEqual(self.testClient.captureFatalEventInvocations.count, 0)
        XCTAssertEqual(sentrycrash_getReportCount(), 0)
    }
    
    private func givenSutWithStartedSDK() {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryCrashInstallationReporterTests")
        options.setIntegrations([SentryCrashIntegration.self])
        SentrySDK.start(options: options)
        
        testClient = TestClient(options: options)
        let hub = SentryHub(client: testClient, andScope: nil)
        SentrySDKInternal.setCurrentHub(hub)
        
        sut = SentryCrashInstallationReporter(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: []), crashWrapper: TestSentryCrashWrapper.sharedInstance(), dispatchQueue: TestSentryDispatchQueueWrapper())
        sut.install(options.cacheDirectoryPath)
        // Works only if SentryCrash is installed
        sentrycrash_deleteAllReports()
    }
}
