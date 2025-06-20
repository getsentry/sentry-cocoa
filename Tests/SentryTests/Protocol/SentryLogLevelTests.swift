@testable import Sentry
import XCTest

final class SentryLogLevelTests: XCTestCase {
    
    // MARK: - Encoding Tests
    
    func testEncodeTrace() throws {
        let level = SentryLogLevel.trace
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"trace\"")
    }
    
    func testEncodeDebug() throws {
        let level = SentryLogLevel.debug
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"debug\"")
    }
    
    func testEncodeInfo() throws {
        let level = SentryLogLevel.info
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"info\"")
    }
    
    func testEncodeWarn() throws {
        let level = SentryLogLevel.warn
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"warn\"")
    }
    
    func testEncodeError() throws {
        let level = SentryLogLevel.error
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"error\"")
    }
    
    func testEncodeFatal() throws {
        let level = SentryLogLevel.fatal
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"fatal\"")
    }
    
    // MARK: - Decoding Tests
    
    func testDecodeTrace() throws {
        let jsonData = Data("\"trace\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?)
        
        XCTAssertEqual(level, .trace)
    }
    
    func testDecodeDebug() throws {
        let jsonData = Data("\"debug\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?)
        
        XCTAssertEqual(level, .debug)
    }
    
    func testDecodeInfo() throws {
        let jsonData = Data("\"info\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?)
        
        XCTAssertEqual(level, .info)
    }
    
    func testDecodeWarn() throws {
        let jsonData = Data("\"warn\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?)
        
        XCTAssertEqual(level, .warn)
    }
    
    func testDecodeError() throws {
        let jsonData = Data("\"error\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?)
        
        XCTAssertEqual(level, .error)
    }
    
    func testDecodeFatal() throws {
        let jsonData = Data("\"fatal\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?)
        
        XCTAssertEqual(level, .fatal)
    }
    
    // MARK: - Error Cases
    
    func testDecodeInvalidString_ReturnsNil() {
        let jsonData = Data("\"invalid\"".utf8)
        
        let level = decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?
        
        XCTAssertNil(level)
    }
    
    func testDecodeEmptyString_ReturnsNil() {
        let jsonData = Data("\"\"".utf8)
        
        let level = decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?
        
        XCTAssertNil(level)
    }
    
    func testDecodeCaseSensitive_ReturnsNil() {
        let jsonData = Data("\"TRACE\"".utf8)
        
        let level = decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?
        
        XCTAssertNil(level)
    }
    
    func testDecodeWithWhitespace_ReturnsNil() {
        let jsonData = Data("\" trace \"".utf8)
        
        let level = decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?
        
        XCTAssertNil(level)
    }
    
    func testDecodeNonString_ReturnsNil() {
        let jsonData = Data("42".utf8)
        
        let level = decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?
        
        XCTAssertNil(level)
    }
    
    func testDecodeNull_ReturnsNil() {
        let jsonData = Data("null".utf8)
        
        let level = decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?
        
        XCTAssertNil(level)
    }
    
    func testDecodeEmptyData_ReturnsNil() {
        let level = decodeFromJSONData(jsonData: Data()) as SentryLogLevel?
        
        XCTAssertNil(level)
    }
    
    func testDecodeGarbageData_ReturnsNil() {
        let jsonData = Data("garbage".utf8)
        
        let level = decodeFromJSONData(jsonData: jsonData) as SentryLogLevel?
        
        XCTAssertNil(level)
    }
    
    // MARK: - Round-trip Tests
    
    func testRoundTripTrace() throws {
        let original = SentryLogLevel.trace
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLogLevel?)
        
        XCTAssertEqual(decoded, original)
    }
    
    func testRoundTripDebug() throws {
        let original = SentryLogLevel.debug
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLogLevel?)
        
        XCTAssertEqual(decoded, original)
    }
    
    func testRoundTripInfo() throws {
        let original = SentryLogLevel.info
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLogLevel?)
        
        XCTAssertEqual(decoded, original)
    }
    
    func testRoundTripWarn() throws {
        let original = SentryLogLevel.warn
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLogLevel?)
        
        XCTAssertEqual(decoded, original)
    }
    
    func testRoundTripError() throws {
        let original = SentryLogLevel.error
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLogLevel?)
        
        XCTAssertEqual(decoded, original)
    }
    
    func testRoundTripFatal() throws {
        let original = SentryLogLevel.fatal
        
        let data = try JSONEncoder().encode(original)
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLogLevel?)
        
        XCTAssertEqual(decoded, original)
    }
    
    // MARK: - Array Tests
    
    func testEncodeArrayOfLogLevels() throws {
        let levels: [SentryLogLevel] = [.trace, .debug, .info, .warn, .error, .fatal]
        
        let data = try JSONEncoder().encode(levels)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "[\"trace\",\"debug\",\"info\",\"warn\",\"error\",\"fatal\"]")
    }
    
    func testDecodeArrayOfLogLevels() throws {
        let jsonData = Data("[\"trace\",\"debug\",\"info\",\"warn\",\"error\",\"fatal\"]".utf8)
        
        let levels = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as [SentryLogLevel]?)
        
        XCTAssertEqual(levels, [.trace, .debug, .info, .warn, .error, .fatal])
    }
    
    func testDecodeArrayWithInvalidLevel_ReturnsNil() {
        let jsonData = Data("[\"trace\",\"invalid\",\"debug\"]".utf8)
        
        let levels = decodeFromJSONData(jsonData: jsonData) as [SentryLogLevel]?
        
        XCTAssertNil(levels)
    }
    
    // MARK: - Dictionary Tests
    
    func testEncodeLogLevelInDictionary() throws {
        let dict = ["level": SentryLogLevel.error]
        
        let data = try JSONEncoder().encode(dict)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "{\"level\":\"error\"}")
    }
    
    func testDecodeLogLevelFromDictionary() throws {
        let jsonData = Data("{\"level\":\"warn\"}".utf8)
        
        let dict = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as [String: SentryLogLevel]?)
        
        XCTAssertEqual(dict["level"], .warn)
    }
    
    // MARK: - Value Property Tests
    
    func testValuePropertyMatchesEncoding() throws {
        let levels: [SentryLogLevel] = [.trace, .debug, .info, .warn, .error, .fatal]
        
        for level in levels {
            let data = try JSONEncoder().encode(level)
            let jsonString = String(data: data, encoding: .utf8)
            let expectedString = "\"\(level.value)\""
            
            XCTAssertEqual(jsonString, expectedString, "Failed for level: \(level)")
        }
    }
}
