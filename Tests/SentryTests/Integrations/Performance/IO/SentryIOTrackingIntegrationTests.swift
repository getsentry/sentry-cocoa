import Foundation

import Sentry
import XCTest

class SentryIOTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let tracker = SentryPerformanceTracker()
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
            fileURL = paths[0].appendingPathComponent("TestFile")
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
    
    private func assertSpans(_ spansCount: Int = 0, _ block : () -> Void) {
        let parentTransaction = SentrySDK.startTransaction(name: "Transaction", operation: "Test", bindToScope: true) as? SentryTracer
        
        block()
        
        let children = Dynamic(parentTransaction).children as [Span]?
        XCTAssertEqual(children?.count, spansCount)
    }
}
