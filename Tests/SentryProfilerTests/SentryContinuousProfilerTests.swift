import _SentryPrivate
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

final class SentryContinuousProfilerTests: XCTestCase {
    private var fixture: SentryProfileTestFixture!
    
    override class func setUp() {
        super.setUp()
        SentryLog.configure(true, diagnosticLevel: .debug)
    }
    
    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
    }
    
    func testStartingAndStoppingContinuousProfiler() throws {
        try performContinuousProfilingTest()
    }
}

private extension SentryContinuousProfilerTests {
    func performContinuousProfilingTest() throws {
        SentryContinuousProfiler.start()
        
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        
        try addMockSamples()
        SentryContinuousProfiler.stop()
        
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())

        //swiftlint:disable todo
        // TODO: assert valid continuous profiling data when schema changes are implemented
        //swiftlint:enable todo
    }
    
    func addMockSamples(threadMetadata: SentryProfileTestFixture.ThreadMetadata = SentryProfileTestFixture.ThreadMetadata(id: 1, priority: 2, name: "main"), addresses: [NSNumber] = [0x3, 0x4, 0x5]) throws {
        let state = try XCTUnwrap(SentryContinuousProfiler.profiler()?.state)
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, addresses: addresses)
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, addresses: addresses)
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, addresses: addresses)
    }
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
