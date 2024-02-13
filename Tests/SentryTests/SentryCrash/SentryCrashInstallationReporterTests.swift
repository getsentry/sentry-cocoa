import Nimble
@testable import Sentry
import SentryTestUtils
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
            expect(filteredReports?.count) == 1
        }
        
        expect(self.testClient.captureCrashEventInvocations.count) == 1
        expect(sentrycrash_getReportCount()) == 0
    }
    
    /**
     * Validates that handling a crash report with the removed fields total_storage and free_storage works.
     */
    func testShouldCaptureCrashReportWithLegacyStorageInfo() throws {
        givenSutWithStartedSDK()
        
        try givenStoredSentryCrashReport(resource: "Resources/crash-report-legacy-storage-info")

        sut.sendAllReports { filteredReports, _, _ in
            expect(filteredReports?.count) == 1
        }
        
        expect(self.testClient.captureCrashEventInvocations.count) == 1
        expect(sentrycrash_getReportCount()) == 0
        
        let event = self.testClient.captureCrashEventInvocations.last?.event
        expect(event?.context?["device"]?["free_storage"]) == nil
        // total_storage got converted to storage_size
        expect(event?.context?["device"]?["storage_size"]) == nil
    }
    
    func testShouldCaptureCrashReportWithoutDeviceContext() throws {
        givenSutWithStartedSDK()
        
        try givenStoredSentryCrashReport(resource: "Resources/crash-report-without-device-context")

        sut.sendAllReports { filteredReports, _, _ in
            expect(filteredReports?.count) == 1
        }
        
        expect(self.testClient.captureCrashEventInvocations.count) == 1
        expect(sentrycrash_getReportCount()) == 0
        
        let event = self.testClient.captureCrashEventInvocations.last?.event
        expect(event?.context?["device"]) == nil
        expect(event?.context?["app"]?["app_name"] as? String) == "iOS-Swift"
    }
    
    func testFaultyReportIsNotSentAndDeleted() throws {
        givenSutWithStartedSDK()
        
        try givenStoredSentryCrashReport(resource: "Resources/Crash-faulty-report")

        sut.sendAllReports { filteredReports, _, _ in
            expect(filteredReports?.count) == 0
        }
        
        expect(self.testClient.captureCrashEventInvocations.count) == 0
        expect(sentrycrash_getReportCount()) == 0
    }
    
    private func givenSutWithStartedSDK() {
        let options = Options()
        options.dsn = TestConstants.dsnAsString(username: "SentryCrashInstallationReporterTests")
        options.setIntegrations([SentryCrashIntegration.self])
        SentrySDK.start(options: options)
        
        testClient = TestClient(options: options)
        let hub = SentryHub(client: testClient, andScope: nil)
        SentrySDK.setCurrentHub(hub)
        
        sut = SentryCrashInstallationReporter(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: []), crashWrapper: TestSentryCrashWrapper.sharedInstance(), dispatchQueue: TestSentryDispatchQueueWrapper())
        sut.install(options.cacheDirectoryPath)
        // Works only if SentryCrash is installed
        sentrycrash_deleteAllReports()
    }
}
