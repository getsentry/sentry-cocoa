import XCTest

class SentryNSDataTrackerTests: XCTestCase {

    private class Fixture {
        
        let filePath = "Some Path"
        let sentryPath = try! TestFileManager(options: Options(), andCurrentDateProvider: DefaultCurrentDateProvider.sharedInstance()).sentryPath 
        let dateProvider = TestCurrentDateProvider()
        let data = "SOME DATA".data(using: .utf8)!
        let threadInspector = TestThreadInspector.instance
        let imageProvider = TestDebugImageProvider()

        func getSut() -> SentryNSDataTracker {
            imageProvider.debugImages = [TestData.debugImage]
            SentryDependencyContainer.sharedInstance().debugImageProvider = imageProvider

            threadInspector.allThreads = [TestData.thread2]

            let result = SentryNSDataTracker(threadInspector: threadInspector, processInfoWrapper: TestProcessInfoWrapper())
            CurrentDate.setCurrentDateProvider(dateProvider)
            result.enable()
            return result
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        fixture.getSut().enable()
        SentrySDK.start { $0.enableFileIOTracing = true }
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testConstants() {
        //A test to ensure this constants don't accidentally change
        XCTAssertEqual("file.read", SENTRY_FILE_READ_OPERATION)
        XCTAssertEqual("file.write", SENTRY_FILE_WRITE_OPERATION)
    }
    
    func testWritePathAtomically() {
        let sut = fixture.getSut()
        var methodPath: String?
        var methodAuxiliareFile: Bool?
        
        var result = sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: false) { path, useAuxiliareFile -> Bool in
            methodPath = path
            methodAuxiliareFile = useAuxiliareFile
            return false
        }
       
        XCTAssertEqual(fixture.filePath, methodPath)
        XCTAssertFalse(methodAuxiliareFile!)
        XCTAssertFalse(result)
        
        result = sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: true) { _, useAuxiliareFile -> Bool in
            methodAuxiliareFile = useAuxiliareFile
            return true
        }
        
        XCTAssertTrue(methodAuxiliareFile!)
        XCTAssertTrue(result)
    }
    
    func testWritePathOptionsError() {
        let sut = fixture.getSut()
        var methodPath: String?
        var methodOptions: NSData.WritingOptions?
        var methodError: NSError?
        
        try! sut.measure(fixture.data, writeToFile: fixture.filePath, options: .atomic) { path, writingOption, _ -> Bool in
            methodPath = path
            methodOptions = writingOption
            return true
        }
        
        XCTAssertEqual(fixture.filePath, methodPath)
        XCTAssertEqual(methodOptions, .atomic)
               
        do {
            try sut.measure(fixture.data, writeToFile: fixture.filePath, options: .withoutOverwriting) { _, writingOption, errorPointer -> Bool in
                methodOptions = writingOption
                errorPointer?.pointee = NSError(domain: "Test Error", code: -2, userInfo: nil)
                return false
            }
        } catch {
            methodError = error as NSError?
        }
        
        XCTAssertEqual(methodOptions, .withoutOverwriting)
        XCTAssertEqual(methodError?.domain, "Test Error")
    }
    
    func testWriteAtomically_CheckTrace() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?

        sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: false) { _, _ -> Bool in
            span = self.firstSpan(transaction)
            XCTAssertFalse(span?.isFinished ?? true)
            self.advanceTime(bySeconds: 4)
            return true
        }
        
        assertSpanDuration(span: span, expectedDuration: 4)
        assertDataSpan(span, path: fixture.filePath, operation: SENTRY_FILE_WRITE_OPERATION, size: fixture.data.count)
    }

    func testWriteAtomically_CheckTransaction_DebugImages() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?

        sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: false) { _, _ -> Bool in
            span = self.firstSpan(transaction)
            XCTAssertFalse(span?.isFinished ?? true)
            self.advanceTime(bySeconds: 4)
            return true
        }

        let transactionEvent = Dynamic(transaction).toTransaction().asObject as? Transaction

        XCTAssertNotNil(transactionEvent?.debugMeta)
        XCTAssertTrue(transactionEvent?.debugMeta?.count ?? 0 > 0)
        XCTAssertEqual(transactionEvent?.debugMeta?.first, TestData.debugImage)
    }

    func testWriteAtomically_CheckTransaction_FilterOut_nonProcessFrames() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        let stackTrace = SentryStacktrace(frames: [TestData.mainFrame, TestData.testFrame, TestData.outsideFrame], registers: ["register": "one"])
        let thread = SentryThread(threadId: 0)
        thread.stacktrace = stackTrace
        fixture.threadInspector.allThreads = [thread]

        var span: SentrySpan?

        sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: false) { _, _ -> Bool in
            span = self.firstSpan(transaction) as? SentrySpan
            XCTAssertFalse(span?.isFinished ?? true)
            return true
        }

        XCTAssertEqual(span?.frames?.count ?? 0, 2)
        XCTAssertEqual(span?.frames?.first, TestData.mainFrame)
        XCTAssertEqual(span?.frames?.last, TestData.testFrame)
    }

    func testWriteAtomically_Background() {
        let sut = self.fixture.getSut()
        let expect = expectation(description: "Operation in background thread")
        DispatchQueue.global(qos: .default).async {
            let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
            var span: Span?

            sut.measure(self.fixture.data, writeToFile: self.fixture.filePath, atomically: false) { _, _ -> Bool in
                span = self.firstSpan(transaction)
                XCTAssertFalse(span?.isFinished ?? true)
                self.advanceTime(bySeconds: 4)
                return true
            }

            self.assertSpanDuration(span: span, expectedDuration: 4)
            self.assertDataSpan(span, path: self.fixture.filePath, operation: SENTRY_FILE_WRITE_OPERATION, size: self.fixture.data.count, mainThread: false)
            expect.fulfill()
        }

        wait(for: [expect], timeout: 0.1)
    }
    
    func testWriteWithOptionsAndError_CheckTrace() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?
        
        try! sut.measure(fixture.data, writeToFile: fixture.filePath, options: .atomic) { _, _, _ -> Bool in
            span = self.firstSpan(transaction)
            XCTAssertFalse(span?.isFinished ?? true)
            self.advanceTime(bySeconds: 3)
            return true
        }
        
        assertSpanDuration(span: span, expectedDuration: 3)
        assertDataSpan(span, path: fixture.filePath, operation: SENTRY_FILE_WRITE_OPERATION, size: fixture.data.count)
    }
    
    func testDontTrackSentryFilesWrites() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?
        
        let expect = expectation(description: "")
        try! sut.measure(fixture.data, writeToFile: fixture.sentryPath, options: .atomic) { _, _, _ -> Bool in
            span = self.firstSpan(transaction)
            expect.fulfill()
            return true
        }
        
        XCTAssertNil(span)
        wait(for: [expect], timeout: 0.1)
    }
    
    func testReadFromString() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?
        var usedPath: String?
        
        let data = sut.measureNSData(fromFile: fixture.filePath) { path in
            span = self.firstSpan(transaction)
            usedPath = path
            return self.fixture.data
        }
        
        XCTAssertEqual(usedPath, fixture.filePath)
        XCTAssertEqual(data?.count, fixture.data.count)
        
        assertDataSpan(span, path: fixture.filePath, operation: SENTRY_FILE_READ_OPERATION, size: fixture.data.count)
    }
    
    func testReadFromStringOptionsError() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?
        var usedPath: String?
        var usedOptions: NSData.ReadingOptions?
        
        let data = try? sut.measureNSData(fromFile: self.fixture.filePath, options: .uncached) { path, options, _ -> Data in
            span = self.firstSpan(transaction)
            usedOptions = options
            usedPath = path
            return self.fixture.data
        }
        
        XCTAssertEqual(usedPath, fixture.filePath)
        XCTAssertEqual(data?.count, fixture.data.count)
        XCTAssertEqual(usedOptions, .uncached)
        
        assertDataSpan(span, path: fixture.filePath, operation: SENTRY_FILE_READ_OPERATION, size: fixture.data.count)
    }
    
    func testReadFromURLOptionsError() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?
        var usedUrl: URL?
        let url = URL(fileURLWithPath: fixture.filePath)
        var usedOptions: NSData.ReadingOptions?
        
        let data = try? sut.measureNSData(from: url, options: .uncached) { url, options, _ in
            span = self.firstSpan(transaction)
            usedOptions = options
            usedUrl = url
            return self.fixture.data
        }
        
        XCTAssertEqual(usedUrl, url)
        XCTAssertEqual(data?.count, fixture.data.count)
        XCTAssertEqual(usedOptions, .uncached)
        
        assertDataSpan(span, path: url.path, operation: SENTRY_FILE_READ_OPERATION, size: fixture.data.count)
    }
    
    func testDontTrackSentryFilesRead() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?
       
        let expect = expectation(description: "")
        let _ = sut.measureNSData(fromFile: fixture.sentryPath) { _ in
            span = self.firstSpan(transaction)
            expect.fulfill()
            return nil
        }
        
        XCTAssertNil(span)
        wait(for: [expect], timeout: 0.1)
    }
    
    private func firstSpan(_ transaction: Span) -> Span? {
        let result = Dynamic(transaction).children as [Span]?
        return result?.first
    }
    
    private func assertDataSpan(_ span: Span?, path: String, operation: String, size: Int, mainThread: Bool = true ) {
        XCTAssertNotNil(span)
        XCTAssertEqual(span?.operation, operation)
        XCTAssertTrue(span?.isFinished ?? false)
        XCTAssertEqual(span?.data["file.size"] as? Int, size)
        XCTAssertEqual(span?.data["file.path"] as? String, path)
        XCTAssertEqual(span?.data["blocked_main_thread"] as? Bool ?? false, mainThread)

        if mainThread {
            guard let frames = (span as? SentrySpan)?.frames else {
                XCTFail("File IO Span in the main thread has no frames")
                return
            }
            XCTAssertEqual(frames.first, TestData.mainFrame)
            XCTAssertEqual(frames.last, TestData.testFrame)
        }
        
        let lastComponent = (path as NSString).lastPathComponent
        
        if operation == SENTRY_FILE_READ_OPERATION {
            XCTAssertEqual(span?.spanDescription, lastComponent)
        } else {
            let bytesDescription = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .binary)
            XCTAssertEqual(span?.spanDescription ?? "", "\(lastComponent) (\(bytesDescription))")
        }
    }
    
    private func assertSpanDuration(span: Span?, expectedDuration: TimeInterval) {
        let duration = span?.timestamp?.timeIntervalSince(span!.startTimestamp!)
        XCTAssertEqual(duration, expectedDuration)
    }
    
    private func advanceTime(bySeconds: TimeInterval) {
        fixture.dateProvider.setDate(date: fixture.dateProvider.date().addingTimeInterval(bySeconds))
    }
}
