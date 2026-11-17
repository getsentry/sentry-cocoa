@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS) || os(macOS) || os(visionOS)

final class SentryMXRunIdDecoderTests: XCTestCase {
    private static let dsn = TestConstants.dsnForTestCase(type: SentryMXRunIdDecoderTests.self)

    private var fileManager: SentryFileManager!
    private var store: SentryMXRunIdRecordStore!
    private var sut: SentryMXRunIdDecoder!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let options = Options()
        options.dsn = Self.dsn
        let dateProvider = TestCurrentDateProvider()
        fileManager = try XCTUnwrap(SentryFileManager(options: options, dateProvider: dateProvider, dispatchQueueWrapper: TestSentryDispatchQueueWrapper()))
        store = SentryMXRunIdRecordStore(fileManager: fileManager, dateProvider: dateProvider)
        sut = SentryMXRunIdDecoder(store: store)
    }

    override func tearDown() {
        fileManager.deleteAllFolders()
        super.tearDown()
    }

    func testRunId_whenAThreadSpellsARecordedCrumb_shouldReturnItsRunId() throws {
        // -- Arrange --
        givenRecord(runId: "run-1", addresses: [10, 20, 30])
        let tree = try givenCallStackTree(threads: [[1, 2, 3], [100, 10, 20, 30, 200]])

        // -- Act & Assert --
        XCTAssertEqual(sut.runId(of: tree), SentryCurrentRun.ID(rawValue: "run-1"))
    }

    func testRunId_whenCrumbIsTheWholeThread_shouldReturnItsRunId() throws {
        // -- Arrange --
        givenRecord(runId: "run-1", addresses: [10, 20, 30])
        let tree = try givenCallStackTree(threads: [[10, 20, 30]])

        // -- Act & Assert --
        XCTAssertEqual(sut.runId(of: tree), SentryCurrentRun.ID(rawValue: "run-1"))
    }

    func testRunId_whenSeveralRunsAreRecorded_shouldReturnTheOneTheThreadSpells() throws {
        // -- Arrange --
        givenRecord(runId: "run-1", addresses: [10, 20, 30])
        givenRecord(runId: "run-2", addresses: [10, 20, 40])
        let tree = try givenCallStackTree(threads: [[100, 10, 20, 40, 200]])

        // -- Act & Assert --
        XCTAssertEqual(sut.runId(of: tree), SentryCurrentRun.ID(rawValue: "run-2"))
    }

    func testRunId_whenThreadSpellsOnlyPartOfTheCrumb_shouldReturnNil() throws {
        // -- Arrange --
        givenRecord(runId: "run-1", addresses: [10, 20, 30])
        let tree = try givenCallStackTree(threads: [[100, 10, 20, 200]])

        // -- Act & Assert --
        XCTAssertNil(sut.runId(of: tree))
    }

    func testRunId_whenThreadSpellsTheCrumbOutOfOrder_shouldReturnNil() throws {
        // -- Arrange --
        givenRecord(runId: "run-1", addresses: [10, 20, 30])
        let tree = try givenCallStackTree(threads: [[30, 20, 10]])

        // -- Act & Assert --
        XCTAssertNil(sut.runId(of: tree))
    }

    func testRunId_whenNothingIsRecorded_shouldReturnNil() throws {
        // -- Arrange --
        let tree = try givenCallStackTree(threads: [[10, 20, 30]])

        // -- Act & Assert --
        XCTAssertNil(sut.runId(of: tree))
    }

    func testRunId_whenCallStackBranches_shouldFindTheCrumbInABranch() throws {
        // -- Arrange --
        givenRecord(runId: "run-1", addresses: [10, 20])
        let json = """
        {"callStackPerThread": false, "callStacks": [{"callStackRootFrames": [
            {"address": 1, "offsetIntoBinaryTextSegment": 0, "subFrames": [
                {"address": 10, "offsetIntoBinaryTextSegment": 0, "subFrames": [
                    {"address": 99, "offsetIntoBinaryTextSegment": 0},
                    {"address": 20, "offsetIntoBinaryTextSegment": 0}
                ]}
            ]}
        ]}]}
        """
        let tree = try JSONDecoder().decode(SentryMXCallStackTree.self, from: Data(json.utf8))

        // -- Act & Assert --
        XCTAssertEqual(sut.runId(of: tree), SentryCurrentRun.ID(rawValue: "run-1"))
    }

    func testRunId_whenSpelledByAParkedThreadCrumb_shouldReturnItsRunId() throws {
        // The addresses a crumb returns are the frames MetricKit would report for that thread.
        // -- Arrange --
        let addresses = try SentryMXRunIdThreadCrumb.spell("ABC123")
        givenRecord(runId: "run-1", addresses: addresses)
        let tree = try givenCallStackTree(threads: [[1] + addresses + [2, 3]])

        // -- Act & Assert --
        XCTAssertEqual(sut.runId(of: tree), SentryCurrentRun.ID(rawValue: "run-1"))
    }

    // MARK: - Helpers

    private func givenRecord(runId: String, addresses: [UInt64]) {
        store.add(SentryMXRunIdRecord(runId: SentryCurrentRun.ID(rawValue: runId), threadCrumbAddresses: addresses, date: Date()))
    }

    /// Builds a per-thread call stack tree whose threads have the given frames, outermost first.
    private func givenCallStackTree(threads: [[UInt64]]) throws -> SentryMXCallStackTree {
        let callStacks = threads.map { ["threadAttributed": false, "callStackRootFrames": [frame($0[...])]] }
        let json = try JSONSerialization.data(withJSONObject: ["callStackPerThread": true, "callStacks": callStacks])
        return try JSONDecoder().decode(SentryMXCallStackTree.self, from: json)
    }

    private func frame(_ addresses: ArraySlice<UInt64>) -> [String: Any] {
        guard let address = addresses.first else {
            return [:]
        }
        var frame: [String: Any] = ["address": address, "offsetIntoBinaryTextSegment": 0]
        let rest = addresses.dropFirst()
        if !rest.isEmpty {
            frame["subFrames"] = [self.frame(rest)]
        }
        return frame
    }
}

#endif // os(iOS) || os(macOS) || os(visionOS)
