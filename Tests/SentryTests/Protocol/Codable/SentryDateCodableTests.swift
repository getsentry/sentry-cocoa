@testable import Sentry
import SentryTestUtils
import XCTest

final class SentryDateCodableTests: XCTestCase {

    func testDecodeDate_WithTimeIntervalSince1970() throws {
        //Arrange
        let timestamp = 0.012345678
        let date = Date(timeIntervalSince1970: timestamp)
        
        let json = "{\"date\": \(timestamp)}".data(using: .utf8)!
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: json) as SentryDateTestDecodable?)
        
        // Assert
        XCTAssertEqual(date.timeIntervalSince1970, actual.date.timeIntervalSince1970, accuracy: 0.000000001)
    }
    
    func testDecodeDate_WithTimeISO8601Format() throws {
        //Arrange
        let timestamp = 0.012345678
        let date = Date(timeIntervalSince1970: timestamp)
        let isoString = sentry_toIso8601String(date)
        
        // The ISO8601 date format only supports milliseconds precision.
        // Therefore, we convert the ISO date string back to the date.
        let expectedDate = try XCTUnwrap(sentry_fromIso8601String(isoString))

        let json = "{\"date\": \"\(isoString)\"}".data(using: .utf8)!
        
        // Act
        let actual = try XCTUnwrap(decodeFromJSONData(jsonData: json) as SentryDateTestDecodable?)
        
        // Assert
        XCTAssertEqual(expectedDate.timeIntervalSince1970, actual.date.timeIntervalSince1970, accuracy: 0.001)
    }
    
    func testDecodeDate_WithWrongDateFormat() throws {
        //Arrange
        let json = "{\"date\": \"hello\"}".data(using: .utf8)!
        
        // Act & Assert
        XCTAssertNil(decodeFromJSONData(jsonData: json) as SentryDateTestDecodable?)
    }
    
    func testDecodeDate_WithBool() throws {
        //Arrange
        let json = "{\"date\": true}".data(using: .utf8)!
        
        // Act & Assert
        XCTAssertNil(decodeFromJSONData(jsonData: json) as SentryDateTestDecodable?)
    }

}

private struct SentryDateTestDecodable: Decodable {
    let date: Date
}
