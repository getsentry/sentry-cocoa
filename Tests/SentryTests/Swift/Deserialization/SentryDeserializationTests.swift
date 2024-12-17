@testable import Sentry
import XCTest

final class SentryDeserializationTests: XCTestCase {

    func testSentryGeo_WithAllProperties() throws {
        let geo = try XCTUnwrap(TestData.geo.copy() as? Geo)
        let actual = geo.serialize()
        
        let deserializedGeo = SentryDeserialization.deserializeSentryGeo(json: actual)
        
        XCTAssertEqual(geo, deserializedGeo)
    }
    
    func testSentryGeo_WithoutCity() throws {
        let geo = try XCTUnwrap(TestData.geo.copy() as? Geo)
        geo.city = ""
        
        let actual = geo.serialize()
        
        let deserializedGeo = SentryDeserialization.deserializeSentryGeo(json: actual)
        
        XCTAssertEqual(geo, deserializedGeo)
    }

}
