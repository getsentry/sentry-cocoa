import Foundation
import Sentry
import XCTest

class SentryFileIOTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let data = "SOME DATA".data(using: .utf8)!
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
        clearTestState()
    }
    
    func test_WritingTrackingDisabled_forIOOption() {
        SentrySDK.start(options: fixture.getOptions(enableFileIOTracking: false))
        
        assertSpans {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    func test_WritingTrackingDisabled_forSwizzlingOption() {
        SentrySDK.start(options: fixture.getOptions(enableSwizzling: false))
        
        assertSpans {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    func test_WritingTrackingDisabled_forAutoPerformanceTrackingOption() {
        SentrySDK.start(options: fixture.getOptions(enableAutoPerformanceTracking: false))
        
        assertSpans {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    func test_WritingTrackingDisabled_TracingDisabled() {
        SentrySDK.start(options: fixture.getOptions(tracesSampleRate: 0))
        
        assertSpans {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    func test_Writing_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1) {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    func test_WritingWithOption_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1) {
            try? fixture.data.write(to: fixture.fileURL, options: .atomic)
        }
    }
        
    func test_ReadingTrackingDisabled_forIOOption() {
        SentrySDK.start(options: fixture.getOptions(enableFileIOTracking: false))
        
        assertSpans {
            let _ = try? Data(contentsOf: fixture.fileURL)
        }
    }
    
    func test_ReadingTrackingDisabled_forSwizzlingOption() {
        SentrySDK.start(options: fixture.getOptions(enableSwizzling: false))
        
        assertSpans {
            let _ = try? Data(contentsOf: fixture.fileURL)
        }
    }
    
    func test_ReadingTrackingDisabled_forAutoPerformanceTrackingOption() {
        SentrySDK.start(options: fixture.getOptions(enableAutoPerformanceTracking: false))
        
        assertSpans {
            let _ = try? Data(contentsOf: fixture.fileURL)
        }
    }
    
    func test_ReadingTrackingDisabled_TracingDisabled() {
        SentrySDK.start(options: fixture.getOptions(tracesSampleRate: 0))
        
        assertSpans {
            let _ = try? Data(contentsOf: fixture.fileURL)
        }
    }
    
    func test_ReadingURL_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1) {
            let _ = try? Data(contentsOf: fixture.fileURL)
        }
    }
    
    func test_ReadingURLWithOption_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1) {
            let data = try? Data(contentsOf: fixture.fileURL, options: .uncached)
            XCTAssertEqual(data?.count, fixture.data.count)
        }
    }
    
    func test_ReadingFile_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1) {
            let data = NSData(contentsOfFile: fixture.filePath)
            XCTAssertEqual(data?.count, fixture.data.count)
        }
    }
    
    func test_ReadingFileWithOptions_Tracking() {
        SentrySDK.start(options: fixture.getOptions())
        assertSpans(1) {
            let data = try? NSData(contentsOfFile: fixture.filePath, options: .uncached)
            XCTAssertEqual(data?.count, fixture.data.count)
        }
    }
    
    func test_ReadingBigFile() {
        SentrySDK.start(options: fixture.getOptions())
        
        guard let jsonFile = Bundle(for: type(of: self)).path(forResource: "Resources/fatal-error-binary-images-message2", ofType: "json") else {
            XCTFail("Could not open Resource")
            return
        }
        
        assertSpans(1) {
            let data = try? NSData(contentsOfFile: jsonFile, options: .uncached)
            XCTAssertEqual(data?.count, 341_431)
        }
    }
    
    func test_WritingBigFile() {
        guard let jsonFile = Bundle(for: type(of: self)).path(forResource: "Resources/fatal-error-binary-images-message2", ofType: "json") else {
            XCTFail("Could not open Resource")
            return
        }
        
        guard let data = try? NSData(contentsOfFile: jsonFile, options: .uncached) else {
            XCTFail("Could not load File")
            return
        }
        
        SentrySDK.start(options: fixture.getOptions())
        
        assertSpans(1) {
            try? data.write(to: fixture.fileURL, options: .atomic)

            let size = try? fixture.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            
            XCTAssertEqual(size, 341_431)
        }
    }
    
    func test_DataConsistency_readUrl() {
        SentrySDK.start(options: fixture.getOptions())
        
        let randomValue = UUID().uuidString
        try? randomValue.data(using: .utf8)?.write(to: fixture.fileURL, options: .atomic)
        print("\(String(describing: fixture.fileURL))")
        let data = try! Data(contentsOf: fixture.fileURL, options: .uncached)
        let readValue = String(data: data, encoding: .utf8)
        XCTAssertEqual(randomValue, readValue)
    }
    
    func test_DataConsistency_readPath() {
        SentrySDK.start(options: fixture.getOptions())
        
        let randomValue = UUID().uuidString
        try? randomValue.data(using: .utf8)?.write(to: fixture.fileURL, options: .atomic)
        let data = NSData(contentsOfFile: fixture.filePath)! as Data
        let readValue = String(data: data, encoding: .utf8)
        XCTAssertEqual(randomValue, readValue)
    }
    
    private func assertSpans(_ spansCount: Int = 0, _ block : () -> Void) {
        let parentTransaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer
        
        block()
        
        let children = Dynamic(parentTransaction).children as [Span]?
        XCTAssertEqual(children?.count, spansCount)
    }
}
