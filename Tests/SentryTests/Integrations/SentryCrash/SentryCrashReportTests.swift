import SentryTestUtils
import XCTest

class SentryCrashReportTests: XCTestCase {
    
    private class Fixture {
        let testPath: String = NSString.path(withComponents: [NSTemporaryDirectory(), "SentryTest"])
        let reportPath: String
        
        init() {
            reportPath = NSString.path(withComponents: [testPath, "SentryCrashReport.json"])
        }
        
        var sut: SentryCrashScopeObserver {
            return SentryCrashScopeObserver(maxBreadcrumbs: 10)
        }
        
        var scope: Scope {
            return TestData.scopeWith(observer: sut)
        }
    }
    
    private let fixture = Fixture()
    private let fileManager = FileManager.default
    
    override func setUp() {
        super.setUp()
        deleteTestDir()
        createTestDir()
    }
    
    override func tearDown() {
        super.tearDown()
        
        deleteTestDir()
        clearTestState()
    }
        
    func testScopeInCrashReport_IsSameAsSerializingIt() {
        let scope = fixture.scope
        
        assertSerializedUserInfo_SameAsCrashReport(scope: scope)
    }
    
    func testScopeInCrashReport_Cleared_IsSameAsSerializingIt() {
        let scope = fixture.scope
        scope.clear()
        
        assertSerializedUserInfo_SameAsCrashReport(scope: scope)
    }
    
    private func assertSerializedUserInfo_SameAsCrashReport(scope: Scope) {
        serializeToCrashReport(scope: scope)
        writeCrashReport()
        
        let crashReportContents = FileManager.default.contents(atPath: fixture.reportPath) ?? Data()
        do {
            let crashReport: CrashReport = try JSONDecoder().decode(CrashReport.self, from: crashReportContents)
            
            // The serialized scope is stored in user. This was the way to store the scope before declaring an extra area for it.
            // We compare the approach before with the current approach to make sure it's working fine.
            XCTAssertEqual(crashReport.user, crashReport.sentry_sdk_scope)
        } catch {
            XCTFail("Couldn't decode crash report: \(error)")
        }
    }
    
    func testShouldWriteReason_WhenWritingNSException() throws {
        var monitorContext = SentryCrash_MonitorContext()
        
        let reason = "Something bad happened"
        reason.withCString {
            monitorContext.crashReason = $0
            monitorContext.crashType = SentryCrashMonitorTypeNSException
            
            let api = sentrycrashcm_system_getAPI()
            api?.pointee.addContextualInfoToEvent(&monitorContext)
            sentrycrashreport_writeStandardReport(&monitorContext, fixture.reportPath)
        }
        
        let crashReportContents = FileManager.default.contents(atPath: fixture.reportPath) ?? Data()

        let crashReport: CrashReport = try XCTUnwrap( JSONDecoder().decode(CrashReport.self, from: crashReportContents))
            
        XCTAssertEqual(crashReport.crash.error.type, "nsexception")
        XCTAssertEqual(crashReport.crash.error.reason, reason)
        XCTAssertEqual(crashReport.crash.error.nsexception?.reason, reason)
    }
    
    func testShouldNotWriteReason_WhenWritingNSException() {
        var monitorContext = SentryCrash_MonitorContext()
        monitorContext.crashType = SentryCrashMonitorTypeNSException
        
        let api = sentrycrashcm_system_getAPI()
        api?.pointee.addContextualInfoToEvent(&monitorContext)
        sentrycrashreport_writeStandardReport(&monitorContext, fixture.reportPath)
        
        let crashReportContents = FileManager.default.contents(atPath: fixture.reportPath) ?? Data()
        do {
            let crashReport: CrashReport = try JSONDecoder().decode(CrashReport.self, from: crashReportContents)
            
            XCTAssertEqual(crashReport.crash.error.type, "nsexception")
            XCTAssertNil(crashReport.crash.error.reason)
            XCTAssertNil(crashReport.crash.error.nsexception?.reason)
        } catch {
            XCTFail("Couldn't decode crash report: \(error)")
        }
    }
    
    func testCrashReportDoesNotContainBootTime() throws {
        writeCrashReport()
        
        let crashReportContents = FileManager.default.contents(atPath: fixture.reportPath) ?? Data()
        
        let crashReportContentsAsString = try XCTUnwrap(String(data: crashReportContents, encoding: .ascii))
        
        XCTAssertFalse(crashReportContentsAsString.contains("boot_time"), "The crash report must not contain boot_time because Apple forbids sending this information off device see: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api#4278394.")
    }
    
    func testCrashReportContainsMachInfo() throws {
        serializeToCrashReport(scope: fixture.scope)
        
        var monitorContext = SentryCrash_MonitorContext()
        monitorContext.mach.type = EXC_BAD_ACCESS
        monitorContext.mach.code = 1
        monitorContext.mach.subcode = 12
        
        writeCrashReport(monitorContext: monitorContext)
        
        let crashReportContents = try XCTUnwrap( FileManager.default.contents(atPath: fixture.reportPath))
        
        let crashReport: CrashReport = try JSONDecoder().decode(CrashReport.self, from: crashReportContents)
        
        let mach = try XCTUnwrap(crashReport.crash.error.mach)
        XCTAssertEqual(1, mach.exception)
        XCTAssertEqual("EXC_BAD_ACCESS", mach.exception_name)
        XCTAssertEqual(1, mach.code)
        XCTAssertEqual("KERN_INVALID_ADDRESS", mach.code_name)
        XCTAssertEqual(12, mach.subcode)
    }
    
    func testCrashReportContainsStandardMachInfo_WhenMachInfoIsEmpty() throws {
        serializeToCrashReport(scope: fixture.scope)
        writeCrashReport()
        
        let crashReportContents = try XCTUnwrap( FileManager.default.contents(atPath: fixture.reportPath))
        
        let crashReport: CrashReport = try JSONDecoder().decode(CrashReport.self, from: crashReportContents)
        
        let mach = try XCTUnwrap(crashReport.crash.error.mach)
        XCTAssertEqual(0, mach.exception)
        XCTAssertNil(mach.exception_name)
        XCTAssertEqual(0, mach.code)
        XCTAssertNil(mach.code_name)
        XCTAssertEqual(0, mach.subcode)
    }
    
    private func writeCrashReport(monitorContext: SentryCrash_MonitorContext? = nil) {
        var localMonitorContext = monitorContext ?? SentryCrash_MonitorContext()
        
        let api = sentrycrashcm_system_getAPI()
        api?.pointee.addContextualInfoToEvent(&localMonitorContext)
        sentrycrashreport_writeStandardReport(&localMonitorContext, fixture.reportPath)
    }
    
    /**
     * UserInfo is picked up by the crash report when writing a new report.
     */
    private func serializeToCrashReport(scope: Scope) {
        SentryDependencyContainer.sharedInstance().crashReporter.userInfo = scope.serialize()
    }
    
    private func deleteTestDir() {
        do {
            if fileManager.fileExists(atPath: fixture.testPath) {
                try fileManager.removeItem(atPath: fixture.testPath)
            }
        } catch {
            XCTFail("Couldn't delete test dir: \(error)")
        }
    }
    
    private func createTestDir() {
        do {
            try fileManager.createDirectory(atPath: fixture.testPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            XCTFail("Couldn't create test dir: \(error)")
        }
    }
    
    // We parse JSON so it's fine to disable identifier_name
    // swiftlint:disable identifier_name
    struct CrashReport: Decodable {
        let user: CrashReportUserInfo?
        let sentry_sdk_scope: CrashReportUserInfo?
        let crash: Crash
    }
    
    struct Crash: Decodable, Equatable {
        let error: ErrorContext
    }
    
    struct ErrorContext: Decodable, Equatable {
        let type: String?
        let reason: String?
        let nsexception: NSException?
        let mach: Mach?
    }
    
    struct NSException: Decodable, Equatable {
        let name: String?
        let userInfo: String?
        let reason: String?
    }
    
    struct Mach: Decodable, Equatable {
        let exception: Int?
        let exception_name: String?
        let code: Int?
        let code_name: String?
        let subcode: Int?
    }

    struct CrashReportUserInfo: Decodable, Equatable {
        let user: CrashReportUser?
        let dist: String?
        let context: [String: [String: String]]?
        let environment: String?
        let tags: [String: String]?
        let extra: [String: String]?
        let fingerprint: [String]?
        let level: String?
        let breadcrumbs: [CrashReportCrumb]?
    }
    
    struct CrashReportUser: Decodable, Equatable {
        let id: String
        let email: String
        let username: String
        let ip_address: String
        let data: [String: [String: String]]
    }

    struct CrashReportCrumb: Decodable, Equatable {
        let category: String
        let data: [String: [String: String]]
        let level: String
        let message: String
        let timestamp: String
        let type: String
    }
    // swiftlint:enable identifier_name
}
