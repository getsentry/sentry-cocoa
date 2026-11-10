@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

final class SentryFatalRunRecordStoreTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryFatalRunRecordStoreTests.self)

    private var fileManager: SentryFileManager!
    private var dateProvider: TestCurrentDateProvider!
    private var sut: SentryFatalRunRecordStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let options = Options()
        options.dsn = Self.dsn
        dateProvider = TestCurrentDateProvider()
        fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: dateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        sut = SentryFatalRunRecordStore(fileManager: fileManager, dateProvider: dateProvider)
    }

    override func tearDown() {
        fileManager.deleteAllFolders()
        super.tearDown()
    }

    func testRecordForRunId_whenRunWasAdded_shouldReturnItsRecord() throws {
        // -- Arrange --
        let record = SentryFatalRunRecord(runId: SentryCurrentRun.ID(rawValue: "run-1"), reportedBy: .watchdogTermination, date: dateProvider.date())
        sut.add(record)
        sut.add(SentryFatalRunRecord(runId: SentryCurrentRun.ID(rawValue: "run-2"), reportedBy: .crashHandler, date: dateProvider.date()))

        // -- Act --
        let found = sut.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1"))

        // -- Assert --
        XCTAssertEqual(found, record)
    }

    func testRecordForRunId_whenRunWasNotAdded_shouldReturnNil() {
        // -- Act & Assert --
        XCTAssertNil(sut.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1")))
    }

    func testRecordForRunId_whenRecordIsOlderThanRetention_shouldReturnNil() {
        // -- Arrange --
        sut.add(SentryFatalRunRecord(runId: SentryCurrentRun.ID(rawValue: "run-1"), reportedBy: .crashHandler, date: dateProvider.date()))

        // -- Act --
        dateProvider.advance(by: SentryFatalRunRecordStore.retention + 1)

        // -- Assert --
        XCTAssertNil(sut.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1")))
    }

    func testAdd_shouldPersistTheSourceAsItsName() throws {
        // -- Act --
        sut.add(SentryFatalRunRecord(runId: SentryCurrentRun.ID(rawValue: "run-1"), reportedBy: .crashHandler, date: dateProvider.date()))

        // -- Assert --
        let json = try String(contentsOfFile: sut.filePath, encoding: .utf8)
        XCTAssertTrue(json.contains("\"reported_by\":\"crashHandler\""))
        let otherStore = SentryFatalRunRecordStore(fileManager: fileManager, dateProvider: dateProvider)
        XCTAssertEqual(otherStore.record(forRunId: SentryCurrentRun.ID(rawValue: "run-1"))?.reportedBy, .crashHandler)
    }

    func testFileName_shouldDifferFromTheMetricKitRunIdRecords() {
        // -- Act & Assert --
        XCTAssertEqual(SentryFatalRunRecordStore.fileName, "fatal-runs.json")
    }
}
