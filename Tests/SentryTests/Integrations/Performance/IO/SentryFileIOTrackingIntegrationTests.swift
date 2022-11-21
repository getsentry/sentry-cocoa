import Foundation
import Sentry
import XCTest
 
// This test is also executed under iOS-SwiftUITests, because
// GitHub Actions doesn't have simulators for iOS 11 and 10.
// That's why we need to keep it generic, without access
// to any private part of the SDK.
class SentryFileIOTrackingIntegrationTests: SentryBaseUnitTest {

    private class Fixture {
        let data = "SOME DATA".data(using: .utf8) ?? Data()
        let filePath: String!
        let fileURL: URL!
        let fileDirectory: URL!
        
        func getOptions(enableAutoPerformanceTracking: Bool = true, enableFileIOTracking: Bool = true, enableSwizzling: Bool = true, tracesSampleRate: NSNumber = 1) -> Options {
            let result = Options()
            result.enableAutoPerformanceTracking = enableAutoPerformanceTracking
            result.enableFileIOTracking = enableFileIOTracking
            result.enableSwizzling = enableSwizzling
            result.tracesSampleRate = tracesSampleRate
            return result
        }
        
        init() {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            fileDirectory = paths[0]
            fileURL = fileDirectory.appendingPathComponent("TestFile")
            filePath = fileURL?.path
        }
    }
    
    private var fixture: Fixture!
    var deleteFileDirectory = false
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        
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
    }
    
    func test_WritingTrackingDisabled_forIOOption() {
        SentrySDK.start(options: fixture.getOptions(enableFileIOTracking: false))
        
        assertWriteWithNoSpans()
    }
    
    func test_WritingTrackingDisabled_forSwizzlingOption() {
        SentrySDK.start(options: fixture.getOptions(enableSwizzling: false))
        
        assertWriteWithNoSpans()
    }
    
    func test_WritingTrackingDisabled_forAutoPerformanceTrackingOption() {
        SentrySDK.start(options: fixture.getOptions(enableAutoPerformanceTracking: false))
        
        assertWriteWithNoSpans()
    }
    
    func test_WritingTrackingDisabled_TracingDisabled() {
        SentrySDK.start(options: fixture.getOptions(tracesSampleRate: 0))
        
        assertWriteWithNoSpans()
    }
    
    func test_Writing_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1, "file.write") {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    func test_WritingWithOption_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1, "file.write") {
            try? fixture.data.write(to: fixture.fileURL, options: .atomic)
        }
    }
        
    func test_ReadingTrackingDisabled_forIOOption() {
        SentrySDK.start(options: fixture.getOptions(enableFileIOTracking: false))
        
        assertWriteWithNoSpans()
    }
    
    func test_ReadingTrackingDisabled_forSwizzlingOption() {
        SentrySDK.start(options: fixture.getOptions(enableSwizzling: false))
        
        assertWriteWithNoSpans()
    }
    
    func test_ReadingTrackingDisabled_forAutoPerformanceTrackingOption() {
        SentrySDK.start(options: fixture.getOptions(enableAutoPerformanceTracking: false))
        
        assertWriteWithNoSpans()
    }
    
    func test_ReadingTrackingDisabled_TracingDisabled() {
        SentrySDK.start(options: fixture.getOptions(tracesSampleRate: 0))
        
        assertWriteWithNoSpans()
    }
    
    func test_ReadingURL_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1, "file.read") {
            let _ = try? Data(contentsOf: fixture.fileURL)
        }
    }
    
    func test_ReadingURLWithOption_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1, "file.read") {
            let data = try? Data(contentsOf: fixture.fileURL, options: .uncached)
            XCTAssertEqual(data?.count, fixture.data.count)
        }
    }
    
    func test_ReadingFile_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1, "file.read") {
            let data = NSData(contentsOfFile: fixture.filePath)
            XCTAssertEqual(data?.count, fixture.data.count)
        }
    }
    
    func test_ReadingFileWithOptions_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1, "file.read") {
            let data = try? NSData(contentsOfFile: fixture.filePath, options: .uncached)
            XCTAssertEqual(data?.count, fixture.data.count)
        }
    }
    
    func test_ReadingBigFile() {
        SentrySDK.start(options: fixture.getOptions())
        
        guard let jsonFile = getBigFilePath() else {
            XCTFail("Could not open Resource")
            return
        }
        
        assertSpans(1, "file.read") {
            let data = try? NSData(contentsOfFile: jsonFile, options: .uncached)
            XCTAssertEqual(data?.count, 341_431)
        }
    }
    
    func test_WritingBigFile() {
        guard let jsonFile = getBigFilePath() else {
            XCTFail("Could not open Resource")
            return
        }
        
        guard let data = try? NSData(contentsOfFile: jsonFile, options: .uncached) else {
            XCTFail("Could not load File")
            return
        }
        
        SentrySDK.start(options: fixture.getOptions())
        
        assertSpans(1, "file.write") {
            try? data.write(to: fixture.fileURL, options: .atomic)

            let size = try? fixture.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            
            XCTAssertEqual(size, 341_431)
        }
    }
    
    func getBigFilePath() -> String? {
        let bundle = Bundle(for: type(of: self))
        
        return bundle.path(forResource: "Resources/fatal-error-binary-images-message2", ofType: "json")
        ?? bundle.path(forResource: "fatal-error-binary-images-message2", ofType: "json")
    }
    
    func test_DataConsistency_readUrl_disabled() {
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
    
    func test_DataConsistency_readPath_disabled() {
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
    
    private func assertSpans( _ spansCount: Int, _ operation: String, _ description: String = "TestFile", _ block: () -> Void) {
        let parentTransaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true)
        
        block()
        
        let childrenSelector = NSSelectorFromString("children")
        
        guard let children = parentTransaction.perform(childrenSelector).takeUnretainedValue() as? [Span] else {
            XCTFail("Did not found children property from transaction.")
            return
        }
        
        XCTAssertEqual(children.count, spansCount)
        if let first = children.first {
            XCTAssertEqual(first.context.operation, operation)         
        }
    }
}
