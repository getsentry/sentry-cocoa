import Foundation
import Sentry
import SentryTestUtils
import XCTest

class SentryFileIOTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let data = "SOME DATA".data(using: .utf8) ?? Data()
        let filePath: String!
        let fileURL: URL!
        let fileDirectory: URL!

        let invalidFileURL = URL(fileURLWithPath: "/path/to/some/file")

        func getOptions(enableAutoPerformanceTracing: Bool = true, enableFileIOTracing: Bool = true, enableSwizzling: Bool = true, tracesSampleRate: NSNumber = 1) -> Options {
            let result = Options()
            result.enableAutoPerformanceTracing = enableAutoPerformanceTracing
            result.enableFileIOTracing = enableFileIOTracing
            result.enableSwizzling = enableSwizzling
            result.tracesSampleRate = tracesSampleRate
            result.setIntegrations([SentryFileIOTrackingIntegration.self])
            return result
        }
        
        init() throws {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            fileDirectory = try XCTUnwrap(paths.first)
            fileURL = fileDirectory.appendingPathComponent("TestFile")
            filePath = fileURL?.path
        }

        func assertDataWritten(toUrl url: URL, file: StaticString = #file, line: UInt = #line) {
            guard let data = try? Data(contentsOf: url) else {
                XCTFail("Could not load written resource file", file: file, line: line)
                return
            }
            XCTAssertEqual(self.data, data, file: file, line: line)
        }
    }
    
    private var fixture: Fixture!
    var deleteFileDirectory = false
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        
        if  !FileManager.default.fileExists(atPath: fixture.fileDirectory.path) {
            try? FileManager.default.createDirectory(at: fixture.fileDirectory, withIntermediateDirectories: true, attributes: nil)
            deleteFileDirectory = true
        }
        
        try? fixture.data.write(to: fixture.fileURL)
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: fixture.fileURL)
        if deleteFileDirectory {
            try? FileManager.default.removeItem(at: fixture.fileDirectory)
        }
        clearTestState()
        SentrySDK.close()
    }
    
    func test_WritingTrackingDisabled_forIOOption() {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableFileIOTracing: false))

        // -- Assert --
        assertWriteWithNoSpans()
    }
    
    func test_WritingTrackingDisabled_forSwizzlingOption() {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableSwizzling: false))

        // -- Assert --
        assertWriteWithNoSpans()
    }
    
    func test_WritingTrackingDisabled_forAutoPerformanceTrackingOption() {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableAutoPerformanceTracing: false))

        // -- Assert --
        assertWriteWithNoSpans()
    }
    
    func test_WritingTrackingDisabled_TracingDisabled() {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(tracesSampleRate: 0))

        // -- Assert --
        assertWriteWithNoSpans()
    }
    
    func testData_Writing_Tracking() {
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
        assertSpans(expectedSpanCount, "file.write") {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }

    func testData_WritingWithOption_Tracking() {
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
        assertSpans(expectedSpanCount, "file.write") {
            try? fixture.data.write(to: fixture.fileURL, options: .atomic)
        }
    }

    func testDataExtension_Writing_Tracking() throws {
        // -- Arrange --
        // Automatic tracking of Swift.Data is not available starting with iOS 18, macOS 15, tvOS 15.
        // Therefore, the extension method is only tested with these OS versions.
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Data+SentryTracing is not tested on this OS version")
        }
        
        // -- Act & Assert --
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1, "file.write") {
            try? fixture.data.writeWithSentryTracing(to: fixture.fileURL)
        }
        fixture.assertDataWritten(toUrl: fixture.fileURL)
    }

    func testDataExtension_WritingWithOption_Tracking() throws {
        // -- Arrange --
        // Automatic tracking of Swift.Data is not available starting with iOS 18, macOS 15, tvOS 15.
        // Therefore, the extension method is only tested with these OS versions.
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Data+SentryTracing is not tested on this OS version")
        }

        // -- Act & Assert --
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1, "file.write") {
            try? fixture.data.writeWithSentryTracing(to: fixture.fileURL, options: .atomic)
        }
        fixture.assertDataWritten(toUrl: fixture.fileURL)
    }

    func test_ReadingTrackingDisabled_forIOOption() {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableFileIOTracing: false))

        // -- Assert --
        assertWriteWithNoSpans()
    }
    
    func test_ReadingTrackingDisabled_forSwizzlingOption() {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableSwizzling: false))

        // -- Assert --
        assertWriteWithNoSpans()
    }
    
    func test_ReadingTrackingDisabled_forAutoPerformanceTrackingOption() {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(enableAutoPerformanceTracing: false))

        // -- Assert --
        assertWriteWithNoSpans()
    }
    
    func test_ReadingTrackingDisabled_TracingDisabled() {
        // -- Act --
        SentrySDK.start(options: fixture.getOptions(tracesSampleRate: 0))

        // -- Assert --
        assertWriteWithNoSpans()
    }
    
    func testData_ReadingURL_Tracking() {
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
        assertSpans(expectedSpanCount, "file.read") {
            let _ = try? Data(contentsOf: fixture.fileURL)
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
        let data = assertSpans(expectedSpanCount, "file.read") {
            try? Data(contentsOf: fixture.fileURL, options: .uncached)
        }
        XCTAssertEqual(data?.count, fixture.data.count)
    }

    func testDataExtension_ReadingURL_fileExists_shouldBeTraced() throws {
        // -- Arrange --
        // Automatic tracking of Swift.Data is not available starting with iOS 18, macOS 15, tvOS 18.
        // Therefore, the extension method is only tested with these OS versions.
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Data+SentryTracing is not tested on this OS version")
        }
        SentrySDK.start(options: fixture.getOptions())
        // -- Act & Assert --
        let data = assertSpans(1, "file.read") {
            try? Data(contentsOfUrlWithSentryTracing: fixture.fileURL)
        }
        XCTAssertEqual(data?.count, fixture.data.count)
    }

    func testDataExtension_ReadingURL_fileNotFound_shouldStillBeTraced() throws {
        // -- Arrange --
        // Automatic tracking of Swift.Data is not available starting with iOS 18, macOS 15, tvOS 18.
        // Therefore, the extension method is only tested with these OS versions.
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Data+SentryTracing is not tested on this OS version")
        }
        SentrySDK.start(options: fixture.getOptions())
        // -- Act & Assert --
        let data = assertSpans(1, "file.read") {
            try? Data(contentsOfUrlWithSentryTracing: fixture.invalidFileURL)
        }
        XCTAssertNil(data)
    }

    func testDataExtension_ReadingURLWithOption_fileExists_shouldBeTraced() throws {
        // -- Arrange --
        // Automatic tracking of Swift.Data is not available starting with iOS 18, macOS 15, tvOS 18.
        // Therefore, the extension method is only tested with these OS versions.
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Data+SentryTracing is not tested on this OS version")
        }

        // -- Act & Assert --
        SentrySDK.start(options: fixture.getOptions())
        let data = assertSpans(1, "file.read") {
            try? Data(contentsOfUrlWithSentryTracing: fixture.fileURL, options: .uncached)
        }
        XCTAssertEqual(data, fixture.data)
    }

    func testDataExtension_ReadingURLWithOption_fileNotFound_shouldStillBeTraced() throws {
        // -- Arrange --
        // Automatic tracking of Swift.Data is not available starting with iOS 18, macOS 15, tvOS 18.
        // Therefore, the extension method is only tested with these OS versions.
        guard #available(iOS 18, macOS 15, tvOS 18, *) else {
            throw XCTSkip("Data+SentryTracing is not tested on this OS version")
        }

        // -- Act & Assert --
        SentrySDK.start(options: fixture.getOptions())
        let data = assertSpans(1, "file.read") {
            try? Data(
                contentsOfUrlWithSentryTracing: fixture.invalidFileURL,
                options: .uncached
            )
        }
        XCTAssertNil(data)
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
    
    func test_ReadingFileWithOptions_Tracking() {
        // -- Arrange --
        SentrySDK.start(options: fixture.getOptions())

        // -- Act & Assert --
        let data = assertSpans(1, "file.read") {
            try? NSData(contentsOfFile: fixture.filePath, options: .uncached)
        }
        XCTAssertEqual(data?.count, fixture.data.count)
    }
    
    func test_ReadingBigFile() {
        // -- Arrange --
        SentrySDK.start(options: fixture.getOptions())
        guard let jsonFile = getBigFilePath() else {
            XCTFail("Could not open Resource")
            return
        }
        // -- Act & Assert --
        let data = assertSpans(1, "file.read") {
            try? NSData(contentsOfFile: jsonFile, options: .uncached)
        }
        XCTAssertEqual(data?.count, 341_432)
    }
    
    func test_WritingBigFile() {
        // -- Arrange --
        guard let jsonFile = getBigFilePath() else {
            XCTFail("Could not open Resource")
            return
        }
        
        guard let data = try? NSData(contentsOfFile: jsonFile, options: .uncached) else {
            XCTFail("Could not load File")
            return
        }
        
        SentrySDK.start(options: fixture.getOptions())

        // -- Act & Assert --
        assertSpans(1, "file.write") {
            try? data.write(to: fixture.fileURL, options: .atomic)
        }
        let size = try? fixture.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        XCTAssertEqual(size, 341_432)
    }
    
    func getBigFilePath() -> String? {
        let bundle = Bundle(for: type(of: self))
        
        return bundle.path(forResource: "Resources/fatal-error-binary-images-message2", ofType: "json")
        ?? bundle.path(forResource: "fatal-error-binary-images-message2", ofType: "json")
    }
    
    func test_DataConsistency_readUrl() {
        SentrySDK.start(options: fixture.getOptions())
        
        let randomValue = UUID().uuidString
        try? randomValue.data(using: .utf8)?.write(to: fixture.fileURL, options: .atomic)
        print("\(String(describing: fixture.fileURL))")
        guard let data = try? Data(contentsOf: fixture.fileURL, options: .uncached) else {
            XCTFail("Could not load resource file")
            return
        }
        let readValue = String(data: data, encoding: .utf8)
        XCTAssertEqual(randomValue, readValue)
    }
    
    func test_DataConsistency_readPath() {
        SentrySDK.start(options: fixture.getOptions())
        
        let randomValue = UUID().uuidString
        try? randomValue.data(using: .utf8)?.write(to: fixture.fileURL, options: .atomic)
        guard let data = try? NSData(contentsOfFile: fixture.filePath) as Data else {
            XCTFail("Could not load resource file")
            return 
        }
        let readValue = String(data: data, encoding: .utf8)
        XCTAssertEqual(randomValue, readValue)
    }
    
    private func assertWriteWithNoSpans() {
        assertSpans(0, "file.write") {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    private func assertSpans<ReturnValue>(
        _ spansCount: Int,
        _ operation: String,
        _ description: String = "TestFile",
        _ block: () -> ReturnValue,
        file: StaticString = #file,
        line: UInt = #line
    ) -> ReturnValue {
        let parentTransaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        
        let result = block()

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
