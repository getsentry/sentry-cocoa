import Foundation
import Sentry
import SentryTestUtils
import XCTest

class SentryFileIOTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let data = Data("SOME DATA".utf8)
        let filePath: String!
        let fileURL: URL!
        let fileDirectory: URL!
        
        func getOptions(enableAutoPerformanceTracing: Bool = true, enableFileIOTracing: Bool = true, enableSwizzling: Bool = true, enableDataSwizzling: Bool = true, enableFileManagerSwizzling: Bool = true, tracesSampleRate: NSNumber = 1) -> Options {
            let result = Options()
            result.removeAllIntegrations()
            result.enableAutoPerformanceTracing = enableAutoPerformanceTracing
            result.enableFileIOTracing = enableFileIOTracing
            result.enableSwizzling = enableSwizzling
            result.tracesSampleRate = tracesSampleRate
            result.enableDataSwizzling = enableDataSwizzling
            result.enableFileManagerSwizzling = enableFileManagerSwizzling
            return result
        }
        
        init() throws {
            fileDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("SentryFileIOTests")
            fileURL = fileDirectory.appendingPathComponent("TestFile")
            filePath = fileURL?.path
        }

        func assertDataWritten(toUrl url: URL, file: StaticString = #file, line: UInt = #line) throws {
            let data = try Data(contentsOf: url)
            XCTAssertEqual(self.data, data, file: file, line: line)
        }

        var invalidFileUrlToRead: URL {
            URL(fileURLWithPath: "/dev/null")
        }
    }
    
    private var fixture: Fixture!
    private var deleteFileDirectory = false
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        
        if  !FileManager.default.fileExists(atPath: fixture.fileDirectory.path) {
            try FileManager.default.createDirectory(at: fixture.fileDirectory, withIntermediateDirectories: true, attributes: nil)
            deleteFileDirectory = true
        }

        try fixture.data.write(to: fixture.fileURL)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        if FileManager.default.fileExists(atPath: fixture.fileURL.path) {
            try FileManager.default.removeItem(at: fixture.fileURL)
        }
        if deleteFileDirectory && FileManager.default.fileExists(atPath: fixture.fileDirectory.path) {
            try FileManager.default.removeItem(at: fixture.fileDirectory)
        }
        clearTestState()
        SentrySDK.close()
    }
    
    func test_WritingTrackingDisabled_forIOOption() throws {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableFileIOTracing: false))

        // -- Assert --
        try assertWriteWithNoSpans()
    }
    
    func test_WritingTrackingDisabled_forSwizzlingOption() throws {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableSwizzling: false))

        // -- Assert --
        try assertWriteWithNoSpans()
    }
    
    func test_WritingTrackingDisabled_forAutoPerformanceTrackingOption() throws {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableAutoPerformanceTracing: false))

        // -- Assert --
        try assertWriteWithNoSpans()
    }
    
    func test_WritingTrackingDisabled_TracingDisabled() throws {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(tracesSampleRate: 0))

        // -- Assert --
        try assertWriteWithNoSpans()
    }
    
    func testData_Writing_Tracking() throws {
        // -- Arrange --
        let expectedSpanCount: Int
        if #available(iOS 18, macOS 15, tvOS 18, *) {
            // Automatic tracking of Swift.Data is not available starting with iOS 18, macOS 15, tvOS 15
            // By asserting for it *not* working, we can lock down the expected behaviour and notice
            // if it changes again in the future.
            expectedSpanCount = 0
        } else {
            expectedSpanCount = 1
        }

        // -- Act --
        SentrySDK.start(options: fixture.getOptions())

        // -- Assert --
        try assertSpans(expectedSpanCount, "file.write") {
            try fixture.data.write(to: fixture.fileURL)
        }
    }

    func testData_WritingWithOption_Tracking() throws {
        // -- Arrange --
        let expectedSpanCount: Int
        if #available(iOS 18, macOS 15, tvOS 18, *) {
            // Automatic tracking of Swift.Data is not available starting with iOS 18, macOS 15, tvOS 15
            // By asserting for it *not* working, we can lock down the expected behaviour and notice
            // if it changes again in the future.
            expectedSpanCount = 0
        } else {
            expectedSpanCount = 1
        }

        // -- Act --
        SentrySDK.start(options: fixture.getOptions())

        // -- Assert --
        try assertSpans(expectedSpanCount, "file.write") {
            try fixture.data.write(to: fixture.fileURL, options: .atomic)
        }
    }

    func test_ReadingTrackingDisabled_forIOOption() throws {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableFileIOTracing: false))

        // -- Assert --
        try assertWriteWithNoSpans()
    }
    
    func test_ReadingTrackingDisabled_forSwizzlingOption() throws {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableSwizzling: false))

        // -- Assert --
        try assertWriteWithNoSpans()
    }
    
    func test_ReadingTrackingDisabled_forAutoPerformanceTrackingOption() throws {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableAutoPerformanceTracing: false))

        // -- Assert --
        try assertWriteWithNoSpans()
    }
    
    func test_ReadingTrackingDisabled_TracingDisabled() throws {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(tracesSampleRate: 0))

        // -- Assert --
        try assertWriteWithNoSpans()
    }
    
    func testData_ReadingURL_Tracking() throws {
        // -- Arrange --
        let expectedSpanCount: Int
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
            // Automatic tracking of Swift.Data is not available starting with iOS 18, macOS 15, tvOS 15
            // By asserting for it *not* working, we can lock down the expected behaviour and notice
            // if it changes again in the future.
            expectedSpanCount = 0
        } else {
            expectedSpanCount = 1
        }

        // -- Act & Assert --
        SentrySDK.start(options: fixture.getOptions())
        try assertSpans(expectedSpanCount, "file.read") {
            let _ = try Data(contentsOf: fixture.fileURL)
        }
    }

    func testData_ReadingURLWithOption_Tracking() throws {
        // -- Arrange --
        let expectedSpanCount: Int
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
            // Automatic tracking of Swift.Data is not available starting with iOS 18, macOS 15, tvOS 18
            // By asserting for it *not* working, we can lock down the expected behaviour and notice
            // if it changes again in the future.
            expectedSpanCount = 0
        } else {
            expectedSpanCount = 1
        }

        // -- Act & Assert --
        SentrySDK.start(options: fixture.getOptions())
        let data = try assertSpans(expectedSpanCount, "file.read") {
            try Data(contentsOf: fixture.fileURL, options: .uncached)
        }
        XCTAssertEqual(data.count, fixture.data.count)
    }

    func test_ReadingFile_Tracking() {
        // -- Arrange --
        SentrySDK.start(options: fixture.getOptions())

        // -- Act & Assert --
        let data = assertSpans(1, "file.read") {
            NSData(contentsOfFile: fixture.filePath)
        }
        XCTAssertEqual(data?.count, fixture.data.count)
    }
    
    func test_ReadingFileWithOptions_Tracking() throws {
        // -- Arrange --
        SentrySDK.start(options: fixture.getOptions())

        // -- Act & Assert --
        let data = try assertSpans(1, "file.read") {
            try NSData(contentsOfFile: fixture.filePath, options: .uncached)
        }
        XCTAssertEqual(data.count, fixture.data.count)
    }
    
    func test_ReadingBigFile() throws {
        // -- Arrange --
        SentrySDK.start(options: fixture.getOptions())
        guard let jsonFile = getBigFilePath() else {
            XCTFail("Could not open Resource")
            return
        }
        // -- Act & Assert --
        let data = try assertSpans(1, "file.read") {
            try NSData(contentsOfFile: jsonFile, options: .uncached)
        }
        XCTAssertEqual(data.count, 295_760)
    }
    
    func test_WritingBigFile() throws {
        // -- Arrange --
        guard let jsonFile = getBigFilePath() else {
            XCTFail("Could not open Resource")
            return
        }

        let data = try NSData(contentsOfFile: jsonFile, options: .uncached)
        
        SentrySDK.start(options: fixture.getOptions())

        // -- Act & Assert --
        try assertSpans(1, "file.write") {
            try data.write(to: fixture.fileURL, options: .atomic)
        }
        let size = try fixture.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        XCTAssertEqual(size, 295_760)
    }
    
    private func getBigFilePath() -> String? {
        let bundle = Bundle(for: type(of: self))
        
        return bundle.path(forResource: "Resources/fatal-error-binary-images-message2", ofType: "json")
        ?? bundle.path(forResource: "fatal-error-binary-images-message2", ofType: "json")
    }
    
    func test_DataConsistency_readUrl() throws {
        SentrySDK.start(options: fixture.getOptions())

        let randomValue = UUID().uuidString
        try randomValue.data(using: .utf8)?.write(to: fixture.fileURL, options: .atomic)
        print("\(String(describing: fixture.fileURL))")
        let data = try Data(contentsOf: fixture.fileURL, options: .uncached)
        let readValue = String(data: data, encoding: .utf8)
        XCTAssertEqual(randomValue, readValue)
    }
    
    func test_DataConsistency_readPath() throws {
        SentrySDK.start(options: fixture.getOptions())

        let randomValue = UUID().uuidString
        try randomValue.data(using: .utf8)?.write(to: fixture.fileURL, options: .atomic)
        let data = try NSData(contentsOfFile: fixture.filePath) as Data
        let readValue = String(data: data, encoding: .utf8)
        XCTAssertEqual(randomValue, readValue)
    }

    func testEnableDataSwizzling_isNotEnabled_shouldNotSwizzleNSDataMethods() throws {
        // -- Arrange --
        let options = fixture.getOptions(enableDataSwizzling: false)
        SentrySDK.start(options: options)

        // -- Act & Assert --
        try assertWriteWithNoSpans()
    }

    func testDisableFileManagerSwizzling_isNotEnabledAndDataSwizzlingIsEnabled_shouldTrackWithSpan() throws {
        // -- Arrange --
        if #available(iOS 18, macOS 15, tvOS 18, *) {
            throw XCTSkip("File manager swizzling is not available for this OS version")
        }
        /// Older OS versions use `NSData` inside `NSFileManager`, therefore we need to test both swizzling options.
        let options = fixture.getOptions(enableDataSwizzling: true, enableFileManagerSwizzling: false)
        SentrySDK.start(options: options)

        // -- Act & Assert --
        assertSpans(1, "file.write") {
            FileManager.default.createFile(atPath: fixture.filePath, contents: nil)
        }
    }

    func testDisableFileManagerSwizzling_isNotEnabled_shouldNotTrackWithSpan() throws {
        // -- Arrange --
        if #available(iOS 18, macOS 15, tvOS 18, *) {
            throw XCTSkip("File manager swizzling is not available for this OS version")
        }
        /// Older OS versions use `NSData` inside `NSFileManager`, therefore we need to disable both swizzling options.
        let options = fixture.getOptions(enableDataSwizzling: false, enableFileManagerSwizzling: false)
        SentrySDK.start(options: options)

        // -- Act & Assert --
        assertSpans(0, "file.write") {
            FileManager.default.createFile(atPath: fixture.filePath, contents: nil)
        }
    }

    private func assertWriteWithNoSpans() throws {
        try assertSpans(0, "file.write") {
            try fixture.data.write(to: fixture.fileURL)
        }
    }

    @discardableResult
    private func assertSpans<ReturnValue>(
        _ spansCount: Int,
        _ operation: String,
        _ description: String = "TestFile",
        _ block: () throws -> ReturnValue,
        file: StaticString = #file,
        line: UInt = #line
    ) rethrows -> ReturnValue {
        let parentTransaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)

        let result = try block()

        let childrenSelector = NSSelectorFromString("children")
        
        guard let children = parentTransaction.perform(childrenSelector).takeUnretainedValue() as? [Span] else {
            XCTFail("Did not found children property from transaction.", file: file, line: line)
            return result
        }
        
        XCTAssertEqual(children.count, spansCount, "Actual span count is not equal to expected count", file: file, line: line)
        if let first = children.first {
            XCTAssertEqual(first.operation, operation, "Operation for span is not equal to expected operation", file: file, line: line)
        }

        return result
    }
}
