import Foundation

import Sentry
import XCTest

class SentryIOTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let data = "SOME DATA".data(using: .utf8)!
        let filePath: String!
        let fileURL: URL!
        
        var options: Options {
            let result = Options()
            result.enableAutoPerformanceTracking = true
            result.enableIOTracking = true
            result.enableSwizzling = true
            return result
        }
        
        init() {
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let docDir = paths[0]
            if  !FileManager.default.fileExists(atPath: docDir.path) {
                try? FileManager.default.createDirectory(at: docDir, withIntermediateDirectories: true, attributes: nil)
            }
            fileURL = docDir.appendingPathComponent("TestFile")
            filePath = fileURL?.path
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        try? fixture.data.write(to: fixture.fileURL)
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func test_WritingTrackingDisabled_forIOOption() {
        SentrySDK.start { options in
            options.enableAutoPerformanceTracking = true
            options.enableSwizzling = true
            options.enableIOTracking = false
        }
        
        assertSpans {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    func test_WritingTrackingDisabled_forSwizzlingOption() {
        SentrySDK.start { options in
            options.enableAutoPerformanceTracking = true
            options.enableSwizzling = false
            options.enableIOTracking = true
        }
        
        assertSpans {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    func test_WritingTrackingDisabled_forAutoPerformanceTrackingOption() {
        SentrySDK.start { options in
            options.enableAutoPerformanceTracking = false
            options.enableSwizzling = true
            options.enableIOTracking = true
        }
        
        assertSpans {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    func test_Writing_Tracking() {
        SentrySDK.start(options: fixture.options)
        assertSpans(1) {
            try? fixture.data.write(to: fixture.fileURL)
        }
    }
    
    func test_WritingWithOption_Tracking() {
        SentrySDK.start(options: fixture.options)
        assertSpans(1) {
            try? fixture.data.write(to: fixture.fileURL, options: .atomic)
        }
    }
        
    func test_ReadingTrackingDisabled_forIOOption() {
        SentrySDK.start { options in
            options.enableAutoPerformanceTracking = true
            options.enableSwizzling = true
            options.enableIOTracking = false
        }
        
        assertSpans {
            let _ = try? Data(contentsOf: fixture.fileURL)
        }
    }
    
    func test_ReadingTrackingDisabled_forSwizzlingOption() {
        SentrySDK.start { options in
            options.enableAutoPerformanceTracking = true
            options.enableSwizzling = false
            options.enableIOTracking = true
        }
        
        assertSpans {
            let _ = try? Data(contentsOf: fixture.fileURL)
        }
    }
    
    func test_ReadingTrackingDisabled_forAutoPerformanceTrackingOption() {
        SentrySDK.start { options in
            options.enableAutoPerformanceTracking = false
            options.enableSwizzling = true
            options.enableIOTracking = true
        }
        
        assertSpans {
            let _ = try? Data(contentsOf: fixture.fileURL)
        }
    }
    
    func test_ReadingURL_Tracking() {
        SentrySDK.start(options: fixture.options)
        assertSpans(1) {
            let _ = try? Data(contentsOf: fixture.fileURL)
        }
    }
    
    func test_ReadingURLWithOption_Tracking() {
        SentrySDK.start(options: fixture.options)
        assertSpans(1) {
            let data = try? Data(contentsOf: fixture.fileURL, options: .uncached)
            XCTAssertEqual(data?.count, fixture.data.count)
        }
    }
    
    func test_ReadingFile_Tracking() {
        SentrySDK.start(options: fixture.options)
        assertSpans(1) {
            let data = NSData(contentsOfFile: fixture.filePath)
            XCTAssertEqual(data?.count, fixture.data.count)
        }
    }
    
    func test_ReadingFileWithOptions_Tracking() {
        SentrySDK.start(options: fixture.options)
        assertSpans(1) {
            let data = try? NSData(contentsOfFile: fixture.filePath, options: .uncached)
            XCTAssertEqual(data?.count, fixture.data.count)
        }
    }
    
    func test_DataConsistency_readUrl() {
        SentrySDK.start(options: fixture.options)
        
        let randomValue = UUID().uuidString
        try? randomValue.data(using: .utf8)?.write(to: fixture.fileURL, options: .atomic)
        print("\(String(describing: fixture.fileURL))")
        let data = try! Data(contentsOf: fixture.fileURL, options: .uncached)
        let readValue = String(data: data, encoding: .utf8)
        XCTAssertEqual(randomValue, readValue)
    }
    
    func test_DataConsistency_readPath() {
        SentrySDK.start(options: fixture.options)
        
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
