@testable import Sentry
import XCTest

class SentryCrashCTests: XCTestCase {
    func testOnCrash_notCrashedDuringCrashHandling_shouldWriteReportToDisk() throws {
        // -- Arrange --
        var appName = "SentryCrashCTests".cString(using: .utf8)!
        let installDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SentryCrashCTests-\(UUID().uuidString)")
        var installPath = installDir.path.cString(using: .utf8)!
        let expectedReportsDir = installDir.appendingPathComponent("Reports")

        // Smoke test the existence of the directory
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: expectedReportsDir.path
        ))

        // Installing the sentrycrash will setup the exception handler
        sentrycrash_uninstall()
        sentrycrash_install(&appName, &installPath)

        var monitorContext = SentryCrash_MonitorContext()
        monitorContext.crashedDuringCrashHandling = false

        // -- Act --
        // Calling the handle exception will trigger the onCrash handler
        sentrycrashcm_handleException(&monitorContext)

        // -- Assert --
        let reportUrls = try FileManager.default
            .contentsOfDirectory(atPath: expectedReportsDir.path)
        XCTAssertEqual(reportUrls.count, 1)
    }

    func testOnCrash_notCrashedDuringCrashHandling_installFilePathTooLong_shouldNotWriteToDisk() {
        // -- Arrange --
        var appName = "SentryCrashCTests".cString(using: .utf8)!
        let workDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SentryCrashCTests-\(UUID().uuidString)")
        let installDir = workDir.appendingPathComponent(Array(repeating: "X", count: 500).joined())
        var installPath = installDir.path.cString(using: .utf8)!
        let expectedReportsDir = installDir.appendingPathComponent("Reports")

        // Smoke test the existence of the directory
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: expectedReportsDir.path
        ))

        // Installing the sentrycrash will setup the exception handler
        sentrycrash_uninstall()
        sentrycrash_install(&appName, &installPath)

        var monitorContext = SentryCrash_MonitorContext()
        monitorContext.crashedDuringCrashHandling = false

        // -- Act --
        // Calling the handle exception will trigger the onCrash handler
        sentrycrashcm_handleException(&monitorContext)

        // -- Assert --
        // When the path is too long, it is expected that no crash data is written to disk
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: expectedReportsDir.path
        ))
    }

    func testOnCrash_crashedDuringCrashHandling_shouldWriteReportToDisk() throws {
        // -- Arrange --
        var appName = "SentryCrashCTests".cString(using: .utf8)!
        let installDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SentryCrashCTests-\(UUID().uuidString)")
        var installPath = installDir.path.cString(using: .utf8)!
        let expectedReportsDir = installDir.appendingPathComponent("Reports")

        // Smoke test the existence of the directory
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: expectedReportsDir.path
        ))

        // Installing the sentrycrash will setup the exception handler
        sentrycrash_uninstall()
        sentrycrash_install(&appName, &installPath)

        // Initial Crash Context
        var initialMonitorContext = SentryCrash_MonitorContext()
        initialMonitorContext.crashedDuringCrashHandling = false // the first context simulates the initial crash

        // Re-created Crash
        // The following crash context is a minimal version of the crash context created in the `SentryCrashMonitor_NSException`
        var recrashMachineContext = SentryCrashMachineContext()
        sentrycrashmc_getContextForThread(
            sentrycrashthread_self(),
            &recrashMachineContext,
            true
        )
        var cursor = SentryCrashStackCursor()
        let callstack = UnsafeMutablePointer<UInt>.allocate(capacity: 0)
        sentrycrashsc_initWithBacktrace(&cursor, callstack, 0, 0)

        var recrashMonitorContext = SentryCrash_MonitorContext()
        recrashMonitorContext.crashType = SentryCrashMonitorTypeNSException
        withUnsafeMutablePointer(to: &recrashMachineContext) { ptr in
            recrashMonitorContext.offendingMachineContext = ptr
        }
        withUnsafeMutablePointer(to: &cursor) { ptr in
            recrashMonitorContext.stackCursor = UnsafeMutableRawPointer(ptr)
        }

        // -- Act --
        // Calling the handle exception will trigger the onCrash handler
        sentrycrashcm_handleException(&initialMonitorContext)

        // Calling the handler again with 'crashedDuringCrashHandling' will rewrite the crash report
        sentrycrashcm_handleException(&recrashMonitorContext)

        // -- Assert --
        let reportUrls = try FileManager.default
            .contentsOfDirectory(atPath: expectedReportsDir.path)
        XCTAssertEqual(
            reportUrls.count, 2
        )
    }

    func testOnCrash_crashedDuringCrashHandling_shouldRewriteOldCrashAsRecrashReportToDisk() throws {
        // -- Arrange --
        var appName = "SentryCrashCTests".cString(using: .utf8)!
        let workDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SentryCrashCTests-\(UUID().uuidString)")
        var installPath = workDir.path.cString(using: .utf8)!
        let expectedReportsDir = workDir.appendingPathComponent("Reports")

        // Smoke test the existence of the directory
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: expectedReportsDir.path
        ))

        // Installing the sentrycrash will setup the exception handler
        sentrycrash_uninstall()
        sentrycrash_install(&appName, &installPath)

        // Initial Crash Context
        var initialMonitorContext = SentryCrash_MonitorContext()
        initialMonitorContext.crashedDuringCrashHandling = false // the first context simulates the initial crash

        // Re-created Crash
        // The following crash context is a minimal version of the crash context created in the `SentryCrashMonitor_NSException`
        var recrashMachineContext = SentryCrashMachineContext()
        sentrycrashmc_getContextForThread(
            sentrycrashthread_self(),
            &recrashMachineContext,
            true
        )
        var cursor = SentryCrashStackCursor()
        let callstack = UnsafeMutablePointer<UInt>.allocate(capacity: 0)
        sentrycrashsc_initWithBacktrace(&cursor, callstack, 0, 0)

        var recrashMonitorContext = SentryCrash_MonitorContext()
        recrashMonitorContext.crashedDuringCrashHandling = true
        recrashMonitorContext.crashType = SentryCrashMonitorTypeNSException
        withUnsafeMutablePointer(to: &recrashMachineContext) { ptr in
            recrashMonitorContext.offendingMachineContext = ptr
        }
        withUnsafeMutablePointer(to: &cursor) { ptr in
            recrashMonitorContext.stackCursor = UnsafeMutableRawPointer(ptr)
        }

        // -- Act --
        // Calling the handle exception will trigger the onCrash handler
        sentrycrashcm_handleException(&initialMonitorContext)

        // After the first handler, the report will be written to disk.
        // Read it to memory now, as the next handler will edit the file.
        let decodedReport = try readFirstReportFromDisk(reportsDir: expectedReportsDir)

        // Calling the handler again with 'crashedDuringCrashHandling' will rewrite the crash report
        sentrycrashcm_handleException(&recrashMonitorContext)

        // -- Assert --
        let decodedRecrashReport = try readFirstReportFromDisk(reportsDir: expectedReportsDir)

        let recrashReport = decodedRecrashReport["recrash_report"] as! NSDictionary
        XCTAssertEqual(recrashReport, decodedReport)
    }

    func testOnCrash_crashedDuringCrashHandling_installFilePathTooLong_shouldNotWriteToDisk() throws {
        // -- Arrange --
        var appName = "SentryCrashCTests".cString(using: .utf8)!
        let workDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SentryCrashCTests-\(UUID().uuidString)")
        let installDir = workDir.appendingPathComponent(Array(repeating: "X", count: 500).joined())
        var installPath = installDir.path.cString(using: .utf8)!
        let expectedReportsDir = installDir.appendingPathComponent("Reports")

        // Smoke test the existence of the directory
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: expectedReportsDir.path
        ))

        // Installing the sentrycrash will setup the exception handler
        sentrycrash_uninstall()
        sentrycrash_install(&appName, &installPath)

        // Initial Crash Context
        var initialMonitorContext = SentryCrash_MonitorContext()
        initialMonitorContext.crashedDuringCrashHandling = false // the first context simulates the initial crash

        // Re-created Crash
        // The following crash context is a minimal version of the crash context created in the `SentryCrashMonitor_NSException`
        var recrashMachineContext = SentryCrashMachineContext()
        sentrycrashmc_getContextForThread(
            sentrycrashthread_self(),
            &recrashMachineContext,
            true
        )
        var cursor = SentryCrashStackCursor()
        let callstack = UnsafeMutablePointer<UInt>.allocate(capacity: 0)
        sentrycrashsc_initWithBacktrace(&cursor, callstack, 0, 0)

        var recrashMonitorContext = SentryCrash_MonitorContext()
        recrashMonitorContext.crashedDuringCrashHandling = true
        recrashMonitorContext.crashType = SentryCrashMonitorTypeNSException
        withUnsafeMutablePointer(to: &recrashMachineContext) { ptr in
            recrashMonitorContext.offendingMachineContext = ptr
        }
        withUnsafeMutablePointer(to: &cursor) { ptr in
            recrashMonitorContext.stackCursor = UnsafeMutableRawPointer(ptr)
        }

        // -- Act --
        // Calling the handle exception will trigger the onCrash handler
        sentrycrashcm_handleException(&initialMonitorContext)

        // Calling the handler again with 'crashedDuringCrashHandling' will rewrite the crash report
        sentrycrashcm_handleException(&recrashMonitorContext)

        // -- Assert --
        // When the path is too long, it is expected that no crash data is written to disk
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: expectedReportsDir.path
        ))
    }

    // MARK: - Helper

    private func readFirstReportFromDisk(reportsDir: URL) throws -> NSDictionary {
        let reportUrls = try FileManager.default.contentsOfDirectory(atPath: reportsDir.path)
        XCTAssertEqual(reportUrls.count, 1)
        XCTAssertTrue(reportUrls[0].hasPrefix("SentryCrashCTests-report-"))
        XCTAssertTrue(reportUrls[0].hasSuffix(".json"))

        let reportData = try Data(contentsOf: reportsDir.appendingPathComponent(reportUrls[0]))
        let decodedReport = try SentryCrashJSONCodec.decode(
            reportData,
            options: SentryCrashJSONDecodeOptionNone
        ) as! NSDictionary

        return decodedReport
    }
}
