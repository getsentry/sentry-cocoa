#if SDK_V10
@_spi(Private) @testable import Sentry
import SentryTestUtils
import XCTest

final class SentryDefaultThreadInspectorV10Tests: XCTestCase {
    private func makeSut(_ provider: MockSnapshotProvider) -> SentryDefaultThreadInspector {
        SentryDefaultThreadInspector(
            stacktraceBuilder: SentryStacktraceBuilder(crashStackEntryMapper:
                SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: []))),
            snapshotProvider: provider
        )
    }

    func testThreads_whenEnumerationEmpty_shouldReturnEmpty() {
        // -- Arrange --
        let sut = makeSut(MockSnapshotProvider([]))

        // -- Act --
        let current = sut.getCurrentThreads()
        let all = sut.getCurrentThreadsWithStackTrace()

        // -- Assert --
        XCTAssertTrue(current.isEmpty)
        XCTAssertTrue(all.isEmpty)
    }

    func testThreads_whenManySnapshots_shouldPreserveIDsAndPutActualMainThreadFirst() throws {
        // -- Arrange --
        let snapshots: [SentryCapturedThread] = (0..<160).map { (index: Int) in
            let threadId = UInt(index) + 1_000
            return SentryCapturedThread(id: threadId, index: UInt(index), isMain: index == 100,
                isCurrent: index == 0, name: "worker-\(index)", addresses: nil)
        }
        let provider = MockSnapshotProvider(snapshots)
        let sut = makeSut(provider)

        // -- Act --
        let threads = sut.getCurrentThreadsWithStackTrace()

        // -- Assert --
        XCTAssertEqual(threads.count, 160)
        let main = try XCTUnwrap(threads.first)
        XCTAssertEqual(main.threadId, 100)
        XCTAssertEqual(main.name, "worker-100")
        XCTAssertEqual(main.isMain, true)
        XCTAssertEqual(main.current, false)
        let current = try XCTUnwrap(threads.element(at: 1))
        XCTAssertEqual(current.threadId, 0)
        XCTAssertEqual(current.isMain, false)
        XCTAssertEqual(current.current, true)
        XCTAssertNotNil(current.stacktrace)
        XCTAssertEqual(threads.filter { $0.isMain == true }.count, 1)
        XCTAssertTrue(threads.allSatisfy { $0.crashed == false })
        XCTAssertEqual(provider.requests, [true])
    }

    func testThreads_whenAddressesCaptured_shouldReverseFramesWithoutChangingTheirFields() throws {
        // -- Arrange --
        let provider = MockSnapshotProvider([
            SentryCapturedThread(id: 42, index: 7, isMain: true, isCurrent: false, name: "main",
                addresses: [0x1111, 0x2222, 0x3333], isTruncated: true)
        ])
        let sut = makeSut(provider)

        // -- Act --
        let thread = try XCTUnwrap(sut.getCurrentThreadsWithStackTrace().first)

        // -- Assert --
        XCTAssertEqual(thread.threadId, 7)
        XCTAssertEqual(thread.crashed, false, "Truncation does not make the thread crashed")
        let frames = try XCTUnwrap(thread.stacktrace).frames
        XCTAssertEqual(frames.map(\.instructionAddress), [
            "0x0000000000003333", "0x0000000000002222", "0x0000000000001111"
        ])
        XCTAssertTrue(frames.allSatisfy { $0.imageAddress != nil })
        XCTAssertTrue(frames.allSatisfy { $0.symbolAddress == nil })
    }

    func testThreads_whenCaptureSkippedOrUnavailable_shouldKeepMetadata() throws {
        // -- Arrange --
        let provider = MockSnapshotProvider([
            SentryCapturedThread(id: 1, index: 0, isMain: false, isCurrent: false, name: nil, addresses: nil),
            SentryCapturedThread(id: 2, index: 1, isMain: false, isCurrent: false, name: "exited", addresses: [])
        ])
        let sut = makeSut(provider)

        // -- Act --
        let threads = sut.getCurrentThreadsWithStackTrace()

        // -- Assert --
        XCTAssertEqual(threads.count, 2)
        XCTAssertNil(try XCTUnwrap(threads.first).stacktrace)
        XCTAssertNil(try XCTUnwrap(threads.first).name)
        let unavailable = try XCTUnwrap(threads.element(at: 1))
        XCTAssertEqual(unavailable.name, "exited")
        XCTAssertTrue(try XCTUnwrap(unavailable.stacktrace).frames.isEmpty)
    }

    func testCurrentThreads_whenRemoteAddressesPresent_shouldOnlyAttachCurrentStack() throws {
        // -- Arrange --
        let provider = MockSnapshotProvider([
            SentryCapturedThread(id: 1, index: 0, isMain: false, isCurrent: true, name: nil, addresses: nil),
            SentryCapturedThread(id: 2, index: 1, isMain: true, isCurrent: false, name: "main", addresses: [1_234])
        ])
        let sut = makeSut(provider)

        // -- Act --
        let threads = sut.getCurrentThreads()

        // -- Assert --
        XCTAssertNil(try XCTUnwrap(threads.first).stacktrace)
        XCTAssertNotNil(try XCTUnwrap(threads.element(at: 1)).stacktrace)
        XCTAssertEqual(provider.requests, [false])
    }

    func testThreads_whenCalledConcurrently_shouldSerializeProviderAndModelConversion() {
        // -- Arrange --
        let provider = MockSnapshotProvider([
            SentryCapturedThread(id: 1, index: 0, isMain: true, isCurrent: false, name: nil, addresses: [])
        ])
        let sut = makeSut(provider)

        // -- Act --
        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            XCTAssertEqual(sut.getCurrentThreadsWithStackTrace().count, 1)
        }

        // -- Assert --
        XCTAssertEqual(provider.requests, Array(repeating: true, count: 10))
    }

    func testThreads_whenIndependentInspectorsContendWithBusyCapture_shouldFallbackWithoutRemoteStacks() {
        // -- Arrange --
        let acquiredAdmission = sentryThreadSuspensionTryAcquire()
        XCTAssertTrue(acquiredAdmission)
        guard acquiredAdmission else { return }
        defer { sentryThreadSuspensionRelease() }
        let inspectors = [
            SentryDefaultThreadInspector(options: nil),
            SentryDefaultThreadInspector(options: nil)
        ]
        let results = SentryMutex([[SentryThread]]())

        // -- Act --
        DispatchQueue.concurrentPerform(iterations: inspectors.count) { index in
            let threads = inspectors[index].getCurrentThreadsWithStackTrace()
            results.withLock { $0.append(threads) }
        }

        // -- Assert --
        let captured = results.withLock { $0 }
        XCTAssertEqual(captured.count, inspectors.count)
        for threads in captured {
            XCTAssertFalse(threads.isEmpty)
            XCTAssertTrue(threads.contains {
                $0.current == true && !($0.stacktrace?.frames.isEmpty ?? true)
            })
            XCTAssertTrue(threads.allSatisfy {
                $0.current == true || ($0.stacktrace?.frames.isEmpty ?? true)
            })
        }
    }

    func testSystemProvider_whenCreatedBeforeOptions_shouldNotRequireCrashInstallation() {
        // -- Arrange --
        let sut = SentryDefaultThreadInspector(options: nil)

        // -- Act --
        let threads = sut.getCurrentThreadsWithStackTrace()

        // -- Assert --
        XCTAssertFalse(threads.isEmpty)
        XCTAssertTrue(threads.contains { $0.current == false && !($0.stacktrace?.frames.isEmpty ?? true) })
    }

    func testSystemProvider_whenCrashHandlingDisabled_shouldCaptureWithoutSDKInstallation() throws {
        // -- Arrange --
        let options = Options()
        options.enableCrashHandler = false
        let sut = SentryDefaultThreadInspector(options: options)

        // -- Act --
        let threads = sut.getCurrentThreadsWithStackTrace()

        // -- Assert --
        XCTAssertFalse(threads.isEmpty)
        let current = try XCTUnwrap(threads.first { $0.current == true })
        XCTAssertFalse(try XCTUnwrap(current.stacktrace).frames.isEmpty)
        XCTAssertTrue(threads.contains { $0.current == false && !($0.stacktrace?.frames.isEmpty ?? true) })
        XCTAssertEqual(threads.first?.isMain, true)
        XCTAssertNil(sut.getThreadName(0))
    }
}

private final class MockSnapshotProvider: SentryThreadSnapshotProviding {
    private let snapshots: [SentryCapturedThread]
    var requests: [Bool] = []

    init(_ snapshots: [SentryCapturedThread]) {
        self.snapshots = snapshots
    }

    func capture(stacks: Bool) -> [SentryCapturedThread] {
        requests.append(stacks)
        return snapshots
    }

    func name(for thread: UInt) -> String? {
        snapshots.first { $0.id == thread }?.name
    }
}
#endif
