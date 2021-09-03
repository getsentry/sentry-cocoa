@testable import Sentry
import XCTest

@available(OSX 10.10, *)
class SentryCrashInstallationReporterTests: XCTestCase {
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryCrashInstallationReporterTests")
    
    private var testClient: TestClient!
    private var sut: SentryCrashInstallationReporter!
    
    override func setUp() {
        super.setUp()
        sut = SentryCrashInstallationReporter(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: []))
        sut.install()
        // Works only if SentryCrash is installed
        sentrycrash_deleteAllReports()
    }
    
    override func tearDown() {
        super.tearDown()
        sentrycrash_deleteAllReports()
        clearTestState()
    }
    
    func testFaultyReportIsNotSentAndDeleted() throws {
        sdkStarted()
        sentryCrashHasFaultyCrashReport()

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
        testClient = TestClient(options: options)!
        let hub = SentryHub(client: testClient, andScope: nil)
        SentrySDK.setCurrentHub(hub)
    }

    private func sentryCrashHasFaultyCrashReport() {
        do {
            let jsonPath = Bundle(for: type(of: self)).path(forResource: "Resources/Crash-faulty-report", ofType: "json")
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath ?? ""))
            jsonData.withUnsafeBytes { ( bytes: UnsafeRawBufferPointer) -> Void in
                let pointer = bytes.bindMemory(to: Int8.self)
                sentrycrashcrs_addUserReport(pointer.baseAddress, Int32(jsonData.count))
            }
        } catch {
            XCTFail("Failed to store faulty crash report in SentryCrash.")
        }
    }
    
    private func assertNoEventsSent() {
        XCTAssertEqual(0, testClient.captureEventWithScopeArguments.count)
    }
    
    private func assertNoReportsStored() {
        XCTAssertEqual(0, sentrycrash_getReportCount())
    }
}
