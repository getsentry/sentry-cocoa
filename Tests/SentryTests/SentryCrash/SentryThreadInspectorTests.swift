import XCTest

class SentryThreadInspectorTests: XCTestCase {
    
    private class Fixture {
        var testMachineContextWrapper = TestMachineContextWrapper()
        var stacktraceBuilder = TestSentryStacktraceBuilder(crashStackEntryMapper: SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: [])))
        
        func getSut(testWithRealMachineConextWrapper: Bool = false) -> SentryThreadInspector {
            
            let machineContextWrapper = testWithRealMachineConextWrapper ? SentryCrashDefaultMachineContextWrapper() : testMachineContextWrapper as SentryCrashMachineContextWrapper
            let stacktraceBuilder = testWithRealMachineConextWrapper ? SentryStacktraceBuilder(crashStackEntryMapper: SentryCrashStackEntryMapper(inAppLogic: SentryInAppLogic(inAppIncludes: [], inAppExcludes: []))) : self.stacktraceBuilder
            
            return SentryThreadInspector(
                stacktraceBuilder: stacktraceBuilder,
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
        let actual = fixture.getSut().getCurrentThreads()
        XCTAssertEqual(0, actual.count)
    }
    
    func testStacktraceHasFrames() {
        let actual = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreads()
        let stacktrace = actual[0].stacktrace
        
        // The stacktrace has usually more than 40 frames. Feel free to change the number if the tests are failing
        XCTAssertTrue(30 < stacktrace?.frames.count ?? 0, "Not enough stacktrace frames.")
    }
    
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, *)
    func testStacktraceHasFrames_forEveryThread_withStitchAsyncOn() {
        SentrySDK.start { $0.stitchAsyncCode = true }
        assertStackForEveryThread()
    }
    
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, *)
    func testStacktraceHasFrames_forEveryThread() {
        assertStackForEveryThread()
    }
    
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, *)
    func assertStackForEveryThread() {
        
        let queue = DispatchQueue(label: "defaultphil", attributes: [.concurrent, .initiallyInactive])
        
        let expect = expectation(description: "Read every thread")
        expect.expectedFulfillmentCount = 10
        
        let sut = self.fixture.getSut(testWithRealMachineConextWrapper: true)
        for _ in 0..<10 {
            
            queue.async {
                let actual = sut.getCurrentThreadsWithStackTrace()
                
                // Sometimes during tests its possible to have one thread without frames
                // We just need to make sure we retrieve frame information for at least one other thread than the main thread
                var threadsWithFrames = 0
                
                for thr in actual {
                    if (thr.stacktrace?.frames.count ?? 0) >= 1 {
                        threadsWithFrames += 1
                    }
                }
                
                XCTAssertTrue(threadsWithFrames > 1, "Not enough threads with frames")
                
                expect.fulfill()
            }
        }
        
        queue.activate()
        wait(for: [expect], timeout: 10)
    }
    
    func testOnlyCurrentThreadHasStacktrace() {
        let actual = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreads()
        XCTAssertEqual(true, actual[0].current)
        XCTAssertNotNil(actual[0].stacktrace)
        
        XCTAssertEqual(false, actual[1].current)
        XCTAssertNil(actual[1].stacktrace)
    }
    
    func testOnlyFirstThreadIsCurrent() {
        let actual = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreads()
        
        let thread0 = actual[0]
        XCTAssertEqual(true, thread0.current)
        
        let threadCount = actual.count
        for i in 1..<threadCount {
            XCTAssertEqual(false, actual[i].current)
        }
    }
    
    func testStacktraceOnlyForCurrentThread() {
        let actual = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreads()
        
        XCTAssertNotNil(actual[0].stacktrace)
        
        let threadCount = actual.count
        for i in 1..<threadCount {
            let thread = actual[i]
            XCTAssertNil(thread.stacktrace)
        }
    }
    
    func testCrashedIsFalseForAllThreads() {
        let actual = fixture.getSut(testWithRealMachineConextWrapper: true).getCurrentThreads()
        
        let threadCount = actual.count
        for i in 0..<threadCount {
            XCTAssertEqual(false, actual[i].crashed)
        }
    }
    
    func testThreadName() {
        let threadName = "thread.name123"
        fixture.testMachineContextWrapper.threadCount = 1
        fixture.testMachineContextWrapper.threadName = threadName
        
        let actual = fixture.getSut().getCurrentThreads()
        
        XCTAssertEqual(threadName, actual[0].name)
    }
    
    func testThreadNameIsNull() {
        fixture.testMachineContextWrapper.threadName = nil
        fixture.testMachineContextWrapper.threadCount = 1
        
        let actual = fixture.getSut().getCurrentThreads()
        XCTAssertEqual(1, actual.count)
        
        let thread = actual[0]
        XCTAssertEqual("", thread.name)
    }
    
    func testLongThreadName() {
        let threadName = String(repeating: "1", count: 127)
        fixture.testMachineContextWrapper.threadName = threadName
        fixture.testMachineContextWrapper.threadCount = 1
        
        let actual = fixture.getSut().getCurrentThreads()
        XCTAssertEqual(1, actual.count)
        
        let thread = actual[0]
        XCTAssertEqual(threadName, thread.name)
    }
    
    func testMainThreadAsFirstThread() {
        fixture.testMachineContextWrapper.mockThreads = [ ThreadInfo(threadId: 2, name: "Second Thread"), ThreadInfo(threadId: 1, name: "main") ]
        fixture.testMachineContextWrapper.mainThread = 1
        fixture.testMachineContextWrapper.threadCount = 2
         
        let sut = fixture.getSut()
        let threads = sut.getCurrentThreads()
        
        XCTAssertEqual(threads[0].name, "main")
        XCTAssertEqual(threads[1].name, "Second Thread")
    }
}

private class TestSentryStacktraceBuilder: SentryStacktraceBuilder {
    
    var stackTraces = [SentryCrashThread: Stacktrace]()
    override func buildStacktrace(forThread thread: SentryCrashThread, context: OpaquePointer) -> Stacktrace {
        return stackTraces[thread] ?? Stacktrace(frames: [], registers: [:])
    }
        
}

private struct ThreadInfo {
    var threadId: SentryCrashThread
    var name: String
}

private class TestMachineContextWrapper: NSObject, SentryCrashMachineContextWrapper {
        
    func fillContext(forCurrentThread context: OpaquePointer) {
        // Do nothing
    }
    
    var threadCount: Int32 = 0
    func getThreadCount(_ context: OpaquePointer) -> Int32 {
        threadCount
    }
    
    var mockThreads: [ThreadInfo]?
    func getThread(_ context: OpaquePointer, with index: Int32) -> SentryCrashThread {
        mockThreads?[Int(index)].threadId ?? 0
    }
    
    var threadName: String? = ""
    func getThreadName(_ thread: SentryCrashThread, andBuffer buffer: UnsafeMutablePointer<Int8>, andBufLength bufLength: Int32) {
        if let mocks = mockThreads, let index = mocks.firstIndex(where: { $0.threadId == thread }) {
            strcpy(buffer, mocks[index].name)
        } else if threadName != nil {
            strcpy(buffer, threadName)
        } else {
            _ = Array(repeating: 0, count: Int(bufLength)).withUnsafeBufferPointer { bufferPointer in
                strcpy(buffer, bufferPointer.baseAddress)
            }
        }
    }
    
    var mainThread: SentryCrashThread?
    func isMainThread(_ thread: SentryCrashThread) -> Bool {
        return thread == mainThread
    }
}
