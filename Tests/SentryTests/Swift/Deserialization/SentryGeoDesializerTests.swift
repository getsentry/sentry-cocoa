@testable import Sentry
import XCTest

final class SentryGeoDesializerTests: XCTestCase {

    func testDeserialize_WithAllProperties() throws {
        let geo = try XCTUnwrap(TestData.geo.copy() as? Geo)
        let actual = geo.serialize()
        
        let deserializedGeo = SentryGeoDesializer.deserialize(json: actual)
        
        XCTAssertEqual(geo, deserializedGeo)
    }
    
    func testDeserialize_WithEmptyCity() throws {
        let geo = try XCTUnwrap(TestData.geo.copy() as? Geo)
        geo.city = ""
        
        let actual = geo.serialize()
        
        let deserializedGeo = SentryGeoDesializer.deserialize(json: actual)
        
        XCTAssertEqual(geo, deserializedGeo)
    }
    
    func testDeserialize_WithEmptyDict() throws {
        let deserializedGeo = SentryGeoDesializer.deserialize(json: [:])
        
        XCTAssertEqual(Geo(), deserializedGeo)
    }

}
