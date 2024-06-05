import Foundation
@testable import Sentry
import XCTest

class SentryReplayOptionsTests: XCTestCase {
    
    func testQualityLow() {
        let options = SentryReplayOptions()
        
        XCTAssertEqual(options.quality, .low)
        XCTAssertEqual(options.replayBitRate, 20_000)
        XCTAssertEqual(options.sizeScale, 0.8)
    }
    
    func testQualityMedium() {
        let options = SentryReplayOptions()
        options.quality = .medium
        
        XCTAssertEqual(options.replayBitRate, 40_000)
        XCTAssertEqual(options.sizeScale, 1.0)
    }
    
    func testQualityHigh() {
        let options = SentryReplayOptions()
        options.quality = .high
        
        XCTAssertEqual(options.replayBitRate, 60_000)
        XCTAssertEqual(options.sizeScale, 1.0)
    }
    
}
