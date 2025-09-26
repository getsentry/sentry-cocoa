@_spi(Private) @testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS)))

class SentryScreenFramesTests: XCTestCase {
    
    // MARK: - Basic Initialization Tests
    
    func testInitWithBasicMetrics() {
        let screenFrames = SentryScreenFrames(total: 100, frozen: 2, slow: 8)
        
        XCTAssertEqual(screenFrames.total, 100)
        XCTAssertEqual(screenFrames.frozen, 2)
        XCTAssertEqual(screenFrames.slow, 8)
        
        #if os(iOS)
        XCTAssertTrue(screenFrames.slowFrameTimestamps.isEmpty)
        XCTAssertTrue(screenFrames.frozenFrameTimestamps.isEmpty)
        XCTAssertTrue(screenFrames.frameRateTimestamps.isEmpty)
        #endif // os(iOS)
    }
    
    func testInitWithZeroValues() {
        let screenFrames = SentryScreenFrames(total: 0, frozen: 0, slow: 0)
        
        XCTAssertEqual(screenFrames.total, 0)
        XCTAssertEqual(screenFrames.frozen, 0)
        XCTAssertEqual(screenFrames.slow, 0)
        
        #if os(iOS)
        XCTAssertTrue(screenFrames.slowFrameTimestamps.isEmpty)
        XCTAssertTrue(screenFrames.frozenFrameTimestamps.isEmpty)
        XCTAssertTrue(screenFrames.frameRateTimestamps.isEmpty)
        #endif // os(iOS)
    }
    
    // MARK: - Profiling Supported Tests
    
    #if os(iOS)
    func testInitWithDetailedMetrics() {
        let slowFrameTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 1_000.0), "value": NSNumber(value: 3)],
            ["timestamp": NSNumber(value: 2_000.0), "value": NSNumber(value: 2)]
        ]
        let frozenFrameTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 3_000.0), "value": NSNumber(value: 1)]
        ]
        let frameRateTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 1_000.0), "value": NSNumber(value: 60.0)],
            ["timestamp": NSNumber(value: 5_000.0), "value": NSNumber(value: 30.0)],
            ["timestamp": NSNumber(value: 7_000.0), "value": NSNumber(value: 10.0)]
        ]
        
        let screenFrames = SentryScreenFrames(
            total: 300,
            frozen: 1,
            slow: 2,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: frozenFrameTimestamps,
            frameRateTimestamps: frameRateTimestamps
        )
        
        XCTAssertEqual(screenFrames.total, 300)
        XCTAssertEqual(screenFrames.frozen, 1)
        XCTAssertEqual(screenFrames.slow, 2)
        
        XCTAssertEqual(screenFrames.slowFrameTimestamps.count, 2)
        XCTAssertEqual(screenFrames.slowFrameTimestamps[0]["timestamp"], 1_000)
        XCTAssertEqual(screenFrames.slowFrameTimestamps[0]["value"], 3)
        XCTAssertEqual(screenFrames.slowFrameTimestamps[1]["timestamp"], 2_000)
        XCTAssertEqual(screenFrames.slowFrameTimestamps[1]["value"], 2)
        
        XCTAssertEqual(screenFrames.frozenFrameTimestamps.count, 1)
        XCTAssertEqual(screenFrames.frozenFrameTimestamps[0]["timestamp"], 3_000)
        XCTAssertEqual(screenFrames.frozenFrameTimestamps[0]["value"], 1)
        
        XCTAssertEqual(screenFrames.frameRateTimestamps.count, 3)
        XCTAssertEqual(screenFrames.frameRateTimestamps[0]["timestamp"], 1_000)
        XCTAssertEqual(screenFrames.frameRateTimestamps[0]["value"], 60)
        XCTAssertEqual(screenFrames.frameRateTimestamps[1]["timestamp"], 5_000)
        XCTAssertEqual(screenFrames.frameRateTimestamps[1]["value"], 30)
        XCTAssertEqual(screenFrames.frameRateTimestamps[2]["timestamp"], 7_000)
        XCTAssertEqual(screenFrames.frameRateTimestamps[2]["value"], 10)
    }
    
    func testInitWithEmptyTimestamps() {
        let screenFrames = SentryScreenFrames(
            total: 50,
            frozen: 0,
            slow: 0,
            slowFrameTimestamps: [],
            frozenFrameTimestamps: [],
            frameRateTimestamps: []
        )
        
        XCTAssertEqual(screenFrames.total, 50)
        XCTAssertTrue(screenFrames.slowFrameTimestamps.isEmpty)
        XCTAssertTrue(screenFrames.frozenFrameTimestamps.isEmpty)
        XCTAssertTrue(screenFrames.frameRateTimestamps.isEmpty)
    }
    #endif // os(iOS)
    
    // MARK: - Description Tests
    
    func testDescription() {
        let screenFrames = SentryScreenFrames(total: 100, frozen: 5, slow: 15)
        let description = screenFrames.description
        
        XCTAssertTrue(description.contains("Total frames: 100"))
        XCTAssertTrue(description.contains("slow frames: 15"))
        XCTAssertTrue(description.contains("frozen frames: 5"))
        
        #if os(iOS)
        XCTAssertTrue(description.contains("slowFrameTimestamps:"))
        XCTAssertTrue(description.contains("frozenFrameTimestamps:"))
        XCTAssertTrue(description.contains("frameRateTimestamps:"))
        #endif // os(iOS)
    }
    
    #if os(iOS)
    func testDescriptionWithTimestamps() {
        let slowFrameTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 1_000.0), "value": NSNumber(value: 1_020.0)]
        ]
        
        let screenFrames = SentryScreenFrames(
            total: 50,
            frozen: 0,
            slow: 1,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: [],
            frameRateTimestamps: []
        )
        
        let description = screenFrames.description
        XCTAssertTrue(description.contains("timestamp"))
        XCTAssertTrue(description.contains("timestamp"))
        XCTAssertTrue(description.contains("1000"))
        XCTAssertTrue(description.contains("1020"))
    }
    #endif // os(iOS)
    
    // MARK: - Equality Tests
    
    func testEqualityWithSameBasicProperties() {
        let screenFrames1 = SentryScreenFrames(total: 100, frozen: 2, slow: 8)
        let screenFrames2 = SentryScreenFrames(total: 100, frozen: 2, slow: 8)
        
        XCTAssertTrue(screenFrames1.isEqual(screenFrames2))
        XCTAssertTrue(screenFrames2.isEqual(screenFrames1))
    }
    
    func testEqualityWithDifferentBasicProperties() {
        let screenFrames1 = SentryScreenFrames(total: 100, frozen: 2, slow: 8)
        let screenFrames2 = SentryScreenFrames(total: 100, frozen: 3, slow: 8)
        
        XCTAssertFalse(screenFrames1.isEqual(screenFrames2))
        XCTAssertFalse(screenFrames2.isEqual(screenFrames1))
    }
    
    func testEqualityWithDifferentTypes() {
        let screenFrames = SentryScreenFrames(total: 100, frozen: 2, slow: 8)
        let otherObject = NSObject()
        
        XCTAssertFalse(screenFrames.isEqual(otherObject))
        XCTAssertFalse(screenFrames.isEqual(nil))
    }
    
    #if os(iOS)
    func testEqualityWithSameTimestamps() {
        let slowFrameTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 1_000.0), "value": NSNumber(value: 1_020.0)]
        ]
        let frozenFrameTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 2_000.0), "value": NSNumber(value: 2_800.0)]
        ]
        let frameRateTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 1_000.0), "value": NSNumber(value: 60.0)]
        ]
        
        let screenFrames1 = SentryScreenFrames(
            total: 100,
            frozen: 1,
            slow: 1,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: frozenFrameTimestamps,
            frameRateTimestamps: frameRateTimestamps
        )
        
        let screenFrames2 = SentryScreenFrames(
            total: 100,
            frozen: 1,
            slow: 1,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: frozenFrameTimestamps,
            frameRateTimestamps: frameRateTimestamps
        )
        
        XCTAssertTrue(screenFrames1.isEqual(screenFrames2))
    }
    
    func testEqualityWithDifferentTimestamps() {
        let slowFrameTimestamps1: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 1_000.0), "value": NSNumber(value: 1_020.0)]
        ]
        let slowFrameTimestamps2: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 2_000.0), "value": NSNumber(value: 2_020.0)]
        ]
        
        let screenFrames1 = SentryScreenFrames(
            total: 100,
            frozen: 0,
            slow: 1,
            slowFrameTimestamps: slowFrameTimestamps1,
            frozenFrameTimestamps: [],
            frameRateTimestamps: []
        )
        
        let screenFrames2 = SentryScreenFrames(
            total: 100,
            frozen: 0,
            slow: 1,
            slowFrameTimestamps: slowFrameTimestamps2,
            frozenFrameTimestamps: [],
            frameRateTimestamps: []
        )
        
        XCTAssertFalse(screenFrames1.isEqual(screenFrames2))
    }
    #endif // os(iOS)
    
    // MARK: - Hash Tests
    
    func testHashConsistency() {
        let screenFrames1 = SentryScreenFrames(total: 100, frozen: 2, slow: 8)
        let screenFrames2 = SentryScreenFrames(total: 100, frozen: 2, slow: 8)
        
        XCTAssertEqual(screenFrames1.hash, screenFrames2.hash)
    }
    
    func testHashDifference() {
        let screenFrames1 = SentryScreenFrames(total: 100, frozen: 2, slow: 8)
        let screenFrames2 = SentryScreenFrames(total: 100, frozen: 3, slow: 8)
        
        XCTAssertNotEqual(screenFrames1.hash, screenFrames2.hash)
    }
    
    #if os(iOS)
    func testHashWithTimestamps() {
        let slowFrameTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 1_000.0), "value": NSNumber(value: 1)]
        ]
        
        let screenFrames1 = SentryScreenFrames(
            total: 100,
            frozen: 0,
            slow: 1,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: [],
            frameRateTimestamps: []
        )
        
        let screenFrames2 = SentryScreenFrames(
            total: 100,
            frozen: 0,
            slow: 1,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: [],
            frameRateTimestamps: []
        )
        
        XCTAssertEqual(screenFrames1.hash, screenFrames2.hash)
    }
    #endif // os(iOS)
    
    // MARK: - NSCopying Tests
    
    #if os(iOS)
    func testCopyWithBasicProperties() {
        let original = SentryScreenFrames(total: 100, frozen: 5, slow: 10)
        let copy = original.copy() as! SentryScreenFrames
        
        XCTAssertTrue(original.isEqual(copy))
        XCTAssertEqual(copy.total, 100)
        XCTAssertEqual(copy.frozen, 5)
        XCTAssertEqual(copy.slow, 10)
        
        // Ensure they are different objects
        XCTAssertFalse(original === copy)
    }
    
    func testCopyWithTimestamps() {
        let slowFrameTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 1_000.0), "value": NSNumber(value: 14.0)]
        ]
        let frozenFrameTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 2_000.0), "value": NSNumber(value: 1.0)]
        ]
        let frameRateTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 1_000.0), "value": NSNumber(value: 60.0)]
        ]
        
        let original = SentryScreenFrames(
            total: 200,
            frozen: 2,
            slow: 5,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: frozenFrameTimestamps,
            frameRateTimestamps: frameRateTimestamps
        )
        
        let copy = original.copy() as! SentryScreenFrames
        
        XCTAssertTrue(original.isEqual(copy))
        XCTAssertEqual(copy.slowFrameTimestamps.count, 1)
        XCTAssertEqual(copy.frozenFrameTimestamps.count, 1)
        XCTAssertEqual(copy.frameRateTimestamps.count, 1)
        
        // Ensure they are different objects
        XCTAssertFalse(original === copy)
    }
    #endif // os(iOS)
    
    // MARK: - Edge Cases
    
    func testLargeValues() {
        let maxUInt = UInt.max
        let screenFrames = SentryScreenFrames(total: maxUInt, frozen: maxUInt, slow: maxUInt)
        
        XCTAssertEqual(screenFrames.total, maxUInt)
        XCTAssertEqual(screenFrames.frozen, maxUInt)
        XCTAssertEqual(screenFrames.slow, maxUInt)
    }
    
    #if os(iOS)
    func testLargeTimestampArrays() {
        // Create a large array to test performance and memory handling
        var largeTimestamps: SentryFrameInfoTimeSeries = []
        for i in 0..<1_000 {
            largeTimestamps.append([
                "timestamp": NSNumber(value: Double(i * 1_000)),
                "value": NSNumber(value: Double(i * 1_000 + 17))
            ])
        }
        
        let screenFrames = SentryScreenFrames(
            total: 1_000,
            frozen: 0,
            slow: 1_000,
            slowFrameTimestamps: largeTimestamps,
            frozenFrameTimestamps: [],
            frameRateTimestamps: []
        )
        
        XCTAssertEqual(screenFrames.slowFrameTimestamps.count, 1_000)
        XCTAssertNotNil(screenFrames.description) // Should not crash
    }
    
    func testTimestampDataIntegrity() {
        let slowFrameTimestamps: SentryFrameInfoTimeSeries = [
            ["timestamp": NSNumber(value: 1_000.5), "value": NSNumber(value: 1_016.7)]
        ]
        
        let screenFrames = SentryScreenFrames(
            total: 1,
            frozen: 0,
            slow: 1,
            slowFrameTimestamps: slowFrameTimestamps,
            frozenFrameTimestamps: [],
            frameRateTimestamps: []
        )
        
        let firstFrame = screenFrames.slowFrameTimestamps[0]
        XCTAssertEqual(firstFrame["timestamp"], NSNumber(value: 1_000.5))
        XCTAssertEqual(firstFrame["value"], NSNumber(value: 1_016.7))
    }
    #endif // os(iOS)
}

#endif // (os(iOS) || os(tvOS) || os(swift(>=5.9) && os(visionOS)))
