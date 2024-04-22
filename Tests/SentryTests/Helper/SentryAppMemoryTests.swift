import XCTest

class SentryAppMemoryTests: XCTestCase {

    func testSerialize() {
        let appMemory = TestData.appMemory
        
        let actual = appMemory.serialize()
        
        XCTAssertEqual(appMemory.footprint, actual["footprint"] as? UInt64)
        XCTAssertEqual(appMemory.remaining, actual["remaining"] as? UInt64)
        XCTAssertEqual(appMemory.limit, actual["limit"] as? UInt64)
        XCTAssertEqual(appMemory.level, SentryAppMemoryLevelFromString(actual["level"] as! String))
        XCTAssertEqual(appMemory.pressure, SentryAppMemoryPressureFromString(actual["pressure"] as! String))
    }
    
    func testInitWithJSON_AllFields() {
        let appMemory = TestData.appMemory
        let dict = [
            "footprint": appMemory.footprint,
            "remaining": appMemory.remaining,
            "pressure": appMemory.pressure,
            
            // unsued. calculated.
            "level": appMemory.level,
            "limit": appMemory.limit,
        ] as [String: Any]
        
        let actual = SentryAppMemory(jsonObject: dict)
        
        XCTAssertEqual(appMemory, actual)
    }
    
    func testLevel() {
        XCTAssertEqual(appMemoryLevel(0, 100), SentryAppMemoryLevel.normal)
        XCTAssertEqual(appMemoryLevel(25, 100), SentryAppMemoryLevel.warn)
        XCTAssertEqual(appMemoryLevel(50, 100), SentryAppMemoryLevel.urgent)
        XCTAssertEqual(appMemoryLevel(75, 100), SentryAppMemoryLevel.critical)
        XCTAssertEqual(appMemoryLevel(95, 100), SentryAppMemoryLevel.terminal)
    }
    
    func appMemoryLevel(_ footprint: UInt64, _ limit: UInt64) -> SentryAppMemoryLevel {
        SentryAppMemory(footprint: footprint, remaining: limit-footprint, pressure: .normal).level
    }
}
