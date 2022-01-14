import XCTest

class SentryNSDataTrackerTests: XCTestCase {

    private class Fixture {
        
        let filePath = "Some Path"
        let sentryPath = try! SentryFileManager(options: Options(), andCurrentDateProvider: DefaultCurrentDateProvider.sharedInstance()).sentryPath 
        let dateProvider = TestCurrentDateProvider()
        let data = "SOME DATA".data(using: .utf8)!
                
        func getSut() -> SentryNSDataTracker {
            let result = SentryNSDataTracker.sharedInstance
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
        SentrySDK.start { $0.enableFileIOTracking = true }
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
    
    private func assertDataSpan(_ span: Span?, path: String, operation: String, size: Int ) {
        XCTAssertNotNil(span)
        XCTAssertEqual(span?.context.operation, operation)
        XCTAssertTrue(span?.isFinished ?? false)
        XCTAssertEqual(span?.data?["file.size"] as? Int, size)
        XCTAssertEqual(span?.data?["file.path"] as? String, path)
        
        let lastComponent = (path as NSString).lastPathComponent
        
        if operation == SENTRY_FILE_READ_OPERATION {
            XCTAssertEqual(span?.context.spanDescription, lastComponent)
        } else {
            let bytesDescription = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .binary)
            XCTAssertEqual(span?.context.spanDescription ?? "", "\(lastComponent) (\(bytesDescription))")
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
