@testable import Sentry
import XCTest

class SentryThreadInspectorTests: XCTestCase {
    
    private class Fixture {
        var testMachineContextWrapper = TestMachineContextWrapper()
        
        func getSut(testWithRealMachineConextWrapper: Bool = false) -> SentryThreadInspector {
            
            let machineContextWrapper = testWithRealMachineConextWrapper ? SentryCrashDefaultMachineContextWrapper() : testMachineContextWrapper as SentryCrashMachineContextWrapper
            
            return SentryThreadInspector(
                stacktraceBuilder: SentryStacktraceBuilder(),
                andMachineContextWrapper: machineContextWrapper
            )
        }
    }
    
    private var fixture: Fixture!
    
    override  func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    func testNoThreads() {
        let actual = fixture.getSut().getCurrentThreadsSkippingFrames(0)
        XCTAssertEqual(0, actual.count)
    }
    
    func testStacktraceHasFrames() {
        let actual = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreadsSkippingFrames(0)
        let stacktrace = actual[0].stacktrace
        
        // The stacktrace has usually more than 40 frames. Feel free to change the number if the tests are failing
        XCTAssertTrue(30 < stacktrace?.frames.count ?? 0, "Not enough stacktrace frames.")
    }
    
    func testOnlyCurrentThreadHasStacktrace() {
        let actual = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreadsSkippingFrames(0)
        XCTAssertEqual(true, actual[0].current)
        XCTAssertNotNil(actual[0].stacktrace)
        
        XCTAssertEqual(false, actual[1].current)
        XCTAssertNil(actual[1].stacktrace)
    }
    
    func testOnlyFirstThreadIsCurrent() {
        let actual = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreadsSkippingFrames(0)
        
        let thread0 = actual[0]
        XCTAssertEqual(true, thread0.current)
        
        let threadCount = actual.count
        for i in 1..<threadCount {
            XCTAssertEqual(false, actual[i].current)
        }
    }
    
    func testStacktraceOnlyForCurrentThread() {
        let actual = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreadsSkippingFrames(0)
        
        XCTAssertNotNil(actual[0].stacktrace)
        
        let threadCount = actual.count
        for i in 1..<threadCount {
            let thread = actual[i]
            XCTAssertNil(thread.stacktrace)
        }
    }
    
    func testCrashedIsFalseForAllThreads() {
        let actual = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreadsSkippingFrames(0)
        
        let threadCount = actual.count
        for i in 0..<threadCount {
            XCTAssertEqual(false, actual[i].crashed)
        }
    }
    
    func testThreadName() {
        let threadName = "thread.name123"
        fixture.testMachineContextWrapper.threadCount = 1
        fixture.testMachineContextWrapper.threadName = threadName
        
        let actual = fixture.getSut().getCurrentThreadsSkippingFrames(0)
        
        XCTAssertEqual(threadName, actual[0].name)
    }
    
    func testThreadNameIsNull() {
        fixture.testMachineContextWrapper.threadName = nil
        fixture.testMachineContextWrapper.threadCount = 1
        
        let actual = fixture.getSut().getCurrentThreadsSkippingFrames(0)
        XCTAssertEqual(1, actual.count)
        
        let thread = actual[0]
        XCTAssertEqual("", thread.name)
    }
    
    func testLongThreadName() {
        let threadName = String(repeating: "1", count: 128)
        fixture.testMachineContextWrapper.threadName = threadName
        fixture.testMachineContextWrapper.threadCount = 1
        
        let actual = fixture.getSut().getCurrentThreadsSkippingFrames(0)
        XCTAssertEqual(1, actual.count)
        
        let thread = actual[0]
        XCTAssertEqual(threadName, thread.name)
    }
    
    func testSkippingFrames() {
        let noSkippedFrames = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreadsSkippingFrames(0)
        
        let skippedFrames = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreadsSkippingFrames(1)
        
        let noSkippedFramesCount = noSkippedFrames[0].stacktrace?.frames.count ?? 0
        let skippedFramesCount = skippedFrames[0].stacktrace?.frames.count ?? 0
        XCTAssertEqual(noSkippedFramesCount - 1, skippedFramesCount)
    }
}

private class TestMachineContextWrapper: NSObject, SentryCrashMachineContextWrapper {
    func fillContext(forCurrentThread context: OpaquePointer) {
        // Do nothing
    }
    
    var threadCount: Int32 = 0
    func getThreadCount(_ context: OpaquePointer) -> Int32 {
        threadCount
    }
    
    func getThread(_ context: OpaquePointer, with index: Int32) -> SentryCrashThread {
        0
    }
    
    var threadName: String? = ""
    func getThreadName(_ thread: SentryCrashThread, andBuffer buffer: UnsafeMutablePointer<Int8>, andBufLength bufLength: Int32) {
        if threadName != nil {
            strcpy(buffer, threadName)
        }
    }
}
