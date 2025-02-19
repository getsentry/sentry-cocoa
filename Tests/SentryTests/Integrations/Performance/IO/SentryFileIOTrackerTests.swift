@testable import Sentry
import SentryTestUtils
import XCTest

class SentryFileIOTrackerTests: XCTestCase {

    private class Fixture {

        let filePath = "Some Path"
        let fileURL = URL(fileURLWithPath: "Some Path")
        let sentryPath = try! TestFileManager(options: Options()).sentryPath
        let sentryUrl = URL(fileURLWithPath: try! TestFileManager(options: Options()).sentryPath)
        let dateProvider = TestCurrentDateProvider()
        let data = "SOME DATA".data(using: .utf8)!
        let threadInspector = TestThreadInspector.instance
        let imageProvider = TestDebugImageProvider()

        func getSut() -> SentryFileIOTracker {
            imageProvider.debugImages = [TestData.debugImage]
            SentryDependencyContainer.sharedInstance().debugImageProvider = imageProvider

            threadInspector.allThreads = [TestData.thread2]

            let processInfoWrapper = TestSentryNSProcessInfoWrapper()
            processInfoWrapper.overrides.processDirectoryPath = "sentrytest"

            let result = SentryFileIOTracker(threadInspector: threadInspector, processInfoWrapper: processInfoWrapper)
            SentryDependencyContainer.sharedInstance().dateProvider = dateProvider
            result.enable()
            return result
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()
        fixture = Fixture()
        fixture.getSut().enable()
        SentrySDK.start {
            $0.removeAllIntegrations()
        }
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testWritePathAtomically() {
        let sut = fixture.getSut()
        var methodPath: String?
        var methodAuxiliareFile: Bool?

        var result = sut.measure(
            fixture.data,
            writeToFile: fixture.filePath,
            atomically: false,
            origin: "custom.origin"
        ) { path, useAuxiliareFile -> Bool in
            methodPath = path
            methodAuxiliareFile = useAuxiliareFile
            return false
        }

        XCTAssertEqual(fixture.filePath, methodPath)
        XCTAssertFalse(methodAuxiliareFile!)
        XCTAssertFalse(result)

        result = sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: true, origin: "custom.origin") { _, useAuxiliareFile -> Bool in
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

        try! sut.measure(fixture.data, writeToFile: fixture.filePath, options: .atomic, origin: "custom.origin") { path, writingOption, _ -> Bool in
            methodPath = path
            methodOptions = writingOption
            return true
        }

        XCTAssertEqual(fixture.filePath, methodPath)
        XCTAssertEqual(methodOptions, .atomic)

        do {
            try sut.measure(fixture.data, writeToFile: fixture.filePath, options: .withoutOverwriting, origin: "custom.origin") { _, writingOption, errorPointer -> Bool in
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

        sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: false, origin: "custom.origin") { _, _ -> Bool in
            span = self.firstSpan(transaction)
            XCTAssertFalse(span?.isFinished ?? true)
            self.advanceTime(bySeconds: 4)
            return true
        }

        assertSpanDuration(span: span, expectedDuration: 4)
        assertDataSpan(span, path: fixture.filePath, operation: SentrySpanOperation.fileWrite, size: fixture.data.count, origin: "custom.origin")
    }

    func testWriteAtomically_CheckTransaction_DebugImages() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?

        sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: false, origin: "custom.origin") { _, _ -> Bool in
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

        sut.measure(fixture.data, writeToFile: fixture.filePath, atomically: false, origin: "custom.origin") { _, _ -> Bool in
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

            sut.measure(self.fixture.data, writeToFile: self.fixture.filePath, atomically: false, origin: "custom.origin") { _, _ -> Bool in
                span = self.firstSpan(transaction)
                XCTAssertFalse(span?.isFinished ?? true)
                self.advanceTime(bySeconds: 4)
                return true
            }

            self.assertSpanDuration(span: span, expectedDuration: 4)
            self.assertDataSpan(span, path: self.fixture.filePath, operation: SentrySpanOperation.fileWrite, size: self.fixture.data.count, origin: "custom.origin", mainThread: false)
            expect.fulfill()
        }

        wait(for: [expect], timeout: 0.1)
    }

    func testWriteWithOptionsAndError_CheckTrace() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?

        try! sut.measure(fixture.data, writeToFile: fixture.filePath, options: .atomic, origin: "custom.origin") { _, _, _ -> Bool in
            span = self.firstSpan(transaction)
            XCTAssertFalse(span?.isFinished ?? true)
            self.advanceTime(bySeconds: 3)
            return true
        }

        assertSpanDuration(span: span, expectedDuration: 3)
        assertDataSpan(span, path: fixture.filePath, operation: SentrySpanOperation.fileWrite, size: fixture.data.count, origin: "custom.origin")
    }

    func testDontTrackSentryFilesWrites() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?

        let expect = expectation(description: "")
        try! sut.measure(fixture.data, writeToFile: fixture.sentryPath, options: .atomic, origin: "custom.origin") { _, _, _ -> Bool in
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

        let data = sut.measureNSData(fromFile: fixture.filePath, origin: "custom.origin") { path in
            span = self.firstSpan(transaction)
            usedPath = path
            return self.fixture.data
        }

        XCTAssertEqual(usedPath, fixture.filePath)
        XCTAssertEqual(data?.count, fixture.data.count)

        assertDataSpan(span, path: fixture.filePath, operation: SentrySpanOperation.fileRead, size: fixture.data.count, origin: "custom.origin")
    }

    func testReadFromStringOptionsError() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?
        var usedPath: String?
        var usedOptions: NSData.ReadingOptions?

        let data = try? sut.measureNSData(fromFile: self.fixture.filePath, options: .uncached, origin: "custom.origin") { path, options, _ -> Data in
            span = self.firstSpan(transaction)
            usedOptions = options
            usedPath = path
            return self.fixture.data
        }

        XCTAssertEqual(usedPath, fixture.filePath)
        XCTAssertEqual(data?.count, fixture.data.count)
        XCTAssertEqual(usedOptions, .uncached)

        assertDataSpan(span, path: fixture.filePath, operation: SentrySpanOperation.fileRead, size: fixture.data.count, origin: "custom.origin")
    }

    func testReadFromURLOptionsError() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?
        var usedUrl: URL?
        let url = URL(fileURLWithPath: fixture.filePath)
        var usedOptions: NSData.ReadingOptions?

        let data = try? sut.measureNSData(from: url, options: .uncached, origin: "custom.origin") { url, options, _ in
            span = self.firstSpan(transaction)
            usedOptions = options
            usedUrl = url
            return self.fixture.data
        }

        XCTAssertEqual(usedUrl, url)
        XCTAssertEqual(data?.count, fixture.data.count)
        XCTAssertEqual(usedOptions, .uncached)

        assertDataSpan(span, path: url.path, operation: SentrySpanOperation.fileRead, size: fixture.data.count, origin: "custom.origin")
    }

    func testCreateFile() {
        let sut = fixture.getSut()

        var methodPath: String?
        var methodData: Data?
        var methodAttributes: [FileAttributeKey: Any]?

        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?

        sut.measureNSFileManagerCreateFile(atPath: fixture.filePath, data: fixture.data, attributes: [
            FileAttributeKey.size: 123
        ], origin: "custom.origin", method: { path, data, attributes in
            methodPath = path
            methodData = data
            methodAttributes = attributes

            span = self.firstSpan(transaction)
            XCTAssertFalse(span?.isFinished ?? true)
            self.advanceTime(bySeconds: 4)

            return true
        })
        XCTAssertEqual(methodPath, fixture.filePath)
        XCTAssertEqual(methodData, fixture.data)
        XCTAssertEqual(methodAttributes?[FileAttributeKey.size] as? Int, 123)

        assertSpanDuration(span: span, expectedDuration: 4)
        assertDataSpan(
            span,
            path: fixture.filePath,
            operation: SentrySpanOperation.fileWrite,
            size: fixture.data.count, origin: "custom.origin"
        )
    }

    func testDontTrackSentryFilesRead() {
        let sut = fixture.getSut()
        let transaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        var span: Span?

        let expect = expectation(description: "")
        let _ = sut.measureNSData(fromFile: fixture.sentryPath, origin: "custom.origin") { _ in
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

    private func assertDataSpan(
        _ span: Span?,
        url: URL,
        operation: String,
        size: Int,
        origin: String,
        mainThread: Bool = true,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assertDataSpan(span, path: url.path, operation: operation, size: size, origin: origin, file: file, line: line)
    }

    private func assertDataSpan(
        _ span: Span?,
        path: String,
        operation: String,
        size: Int,
        origin: String,
        mainThread: Bool = true,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(span, file: file, line: line)
        XCTAssertEqual(span?.operation, operation, file: file, line: line)
        XCTAssertEqual(span?.origin, origin, file: file, line: line)
        XCTAssertTrue(span?.isFinished ?? false, file: file, line: line)
        XCTAssertEqual(span?.data["file.size"] as? Int, size, file: file, line: line)
        XCTAssertEqual(span?.data["file.path"] as? String, path, file: file, line: line)
        XCTAssertEqual(span?.data["blocked_main_thread"] as? Bool ?? false, mainThread)

        if mainThread {
            guard let frames = (span as? SentrySpan)?.frames else {
                XCTFail("File IO Span in the main thread has no frames", file: file, line: line)
                return
            }
            XCTAssertEqual(frames.first, TestData.mainFrame, file: file, line: line)
            XCTAssertEqual(frames.last, TestData.testFrame, file: file, line: line)
        }

        let lastComponent = (path as NSString).lastPathComponent

        if operation == SentrySpanOperation.fileRead {
            XCTAssertEqual(span?.spanDescription, lastComponent, file: file, line: line)
        } else {
            let bytesDescription = SentryByteCountFormatter.bytesCountDescription( UInt(size))
            XCTAssertEqual(span?.spanDescription ?? "", "\(lastComponent) (\(bytesDescription))", file: file, line: line)
        }
    }

    private func assertSpanDuration(
        span: Span?,
        expectedDuration: TimeInterval,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let duration = span?.timestamp?.timeIntervalSince(span!.startTimestamp!)
        XCTAssertEqual(duration, expectedDuration, file: file, line: line)
    }

    private func advanceTime(bySeconds: TimeInterval) {
        fixture.dateProvider.setDate(date: fixture.dateProvider.date().addingTimeInterval(bySeconds))
    }
}
