@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)

final class SentryMXRunIdRecordStoreTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryMXRunIdRecordStoreTests.self)

    private var fileManager: SentryFileManager!
    private var dateProvider: TestCurrentDateProvider!
    private var sut: SentryMXRunIdRecordStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let options = Options()
        options.dsn = Self.dsn
        dateProvider = TestCurrentDateProvider()
        fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: dateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        sut = SentryMXRunIdRecordStore(fileManager: fileManager, dateProvider: dateProvider)
    }

    override func tearDown() {
        fileManager.deleteAllFolders()
        super.tearDown()
    }

    func testRecords_whenNothingWasAdded_shouldBeEmpty() {
        // -- Act & Assert --
        XCTAssertEqual(sut.records(), [])
    }

    func testAdd_shouldPersistTheRecordForAnotherStore() throws {
        // -- Arrange --
        let record = SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-1"), threadCrumbAddresses: [1, 2, 3], date: dateProvider.date())

        // -- Act --
        sut.add(record)

        // -- Assert --
        let otherStore = SentryMXRunIdRecordStore(fileManager: fileManager, dateProvider: dateProvider)
        XCTAssertEqual(otherStore.records(), [record])
    }

    func testAdd_whenTwoStoresWriteTheSameFileConcurrently_shouldKeepEveryRecord() {
        // -- Arrange --
        // Every SDK start creates its own store for the same file.
        let stores = [sut, SentryMXRunIdRecordStore(fileManager: fileManager, dateProvider: dateProvider)]
        let date = dateProvider.date()
        let runCount = 100

        // -- Act --
        DispatchQueue.concurrentPerform(iterations: runCount) { index in
            stores[index % stores.count]?.add(SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-\(index)"), threadCrumbAddresses: [UInt64(index)], date: date))
        }

        // -- Assert --
        XCTAssertEqual(Set(sut.records().map(\.runId.rawValue)), Set((0..<runCount).map { "run-\($0)" }))
    }

    func testAdd_whenCalledForSeveralRuns_shouldKeepThemOldestFirst() {
        // -- Arrange --
        let first = SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-1"), threadCrumbAddresses: [1], date: dateProvider.date())
        dateProvider.advance(by: 60)
        let second = SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-2"), threadCrumbAddresses: [2], date: dateProvider.date())

        // -- Act --
        sut.add(first)
        sut.add(second)

        // -- Assert --
        XCTAssertEqual(sut.records(), [first, second])
    }

    func testAdd_whenRunWasAlreadyRecorded_shouldReplaceItsRecord() {
        // -- Arrange --
        sut.add(SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-1"), threadCrumbAddresses: [1], date: dateProvider.date()))
        let replacement = SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-1"), threadCrumbAddresses: [9], date: dateProvider.date())

        // -- Act --
        sut.add(replacement)

        // -- Assert --
        XCTAssertEqual(sut.records(), [replacement])
    }

    func testRecords_whenRecordIsOlderThanRetention_shouldDropIt() {
        // -- Arrange --
        let old = SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-old"), threadCrumbAddresses: [1], date: dateProvider.date())
        sut.add(old)
        dateProvider.advance(by: SentryMXRunIdRecordStore.retention - 1)
        let recent = SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-recent"), threadCrumbAddresses: [2], date: dateProvider.date())
        sut.add(recent)

        // -- Act --
        dateProvider.advance(by: 2)

        // -- Assert --
        XCTAssertEqual(sut.records(), [recent])
    }

    func testAdd_shouldDropRecordsOlderThanRetentionFromTheFile() throws {
        // -- Arrange --
        sut.add(SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-old"), threadCrumbAddresses: [1], date: dateProvider.date()))
        dateProvider.advance(by: SentryMXRunIdRecordStore.retention + 1)

        // -- Act --
        sut.add(SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-new"), threadCrumbAddresses: [2], date: dateProvider.date()))

        // -- Assert --
        let json = try String(contentsOfFile: sut.filePath, encoding: .utf8)
        XCTAssertFalse(json.contains("run-old"))
        XCTAssertTrue(json.contains("run-new"))
    }

    func testRecords_whenFileIsCorrupt_shouldBeEmpty() {
        // -- Arrange --
        fileManager.write(Data("not json".utf8), toPath: sut.filePath)

        // -- Act & Assert --
        XCTAssertEqual(sut.records(), [])
    }

    func testAdd_whenFileIsCorrupt_shouldStartOver() {
        // -- Arrange --
        fileManager.write(Data("not json".utf8), toPath: sut.filePath)
        let record = SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-1"), threadCrumbAddresses: [1], date: dateProvider.date())

        // -- Act --
        sut.add(record)

        // -- Assert --
        XCTAssertEqual(sut.records(), [record])
    }

    func testAdd_shouldWriteSnakeCaseKeys() throws {
        // -- Act --
        sut.add(SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: "run-1"), threadCrumbAddresses: [1], date: dateProvider.date()))

        // -- Assert --
        let json = try String(contentsOfFile: sut.filePath, encoding: .utf8)
        XCTAssertTrue(json.contains("\"run_id\""))
        XCTAssertTrue(json.contains("\"thread_crumb_addresses\""))
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
