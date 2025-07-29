@testable import Sentry
import XCTest

final class SentryLogLevelTests: XCTestCase {
    
    // MARK: - Encoding Tests
    
    func testEncodeTrace() throws {
        let level = SentryLog.Level.trace
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"trace\"")
    }
    
    func testEncodeDebug() throws {
        let level = SentryLog.Level.debug
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"debug\"")
    }
    
    func testEncodeInfo() throws {
        let level = SentryLog.Level.info
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"info\"")
    }
    
    func testEncodeWarn() throws {
        let level = SentryLog.Level.warn
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"warn\"")
    }
    
    func testEncodeError() throws {
        let level = SentryLog.Level.error
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"error\"")
    }
    
    func testEncodeFatal() throws {
        let level = SentryLog.Level.fatal
        
        let data = try JSONEncoder().encode(level)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "\"fatal\"")
    }
    
    // MARK: - Decoding Tests
    
    func testDecodeTrace() throws {
        let jsonData = Data("\"trace\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLog.Level?)
        
        XCTAssertEqual(level, .trace)
    }
    
    func testDecodeDebug() throws {
        let jsonData = Data("\"debug\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLog.Level?)
        
        XCTAssertEqual(level, .debug)
    }
    
    func testDecodeInfo() throws {
        let jsonData = Data("\"info\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLog.Level?)
        
        XCTAssertEqual(level, .info)
    }
    
    func testDecodeWarn() throws {
        let jsonData = Data("\"warn\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLog.Level?)
        
        XCTAssertEqual(level, .warn)
    }
    
    func testDecodeError() throws {
        let jsonData = Data("\"error\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLog.Level?)
        
        XCTAssertEqual(level, .error)
    }
    
    func testDecodeFatal() throws {
        let jsonData = Data("\"fatal\"".utf8)
        
        let level = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as SentryLog.Level?)
        
        XCTAssertEqual(level, .fatal)
    }
    
    // MARK: - Error Cases
    
    func testDecodeCaseSensitive_ReturnsNil() {
        let jsonData = Data("\"TRACE\"".utf8)
        
        let level = decodeFromJSONData(jsonData: jsonData) as SentryLog.Level?
        
        XCTAssertNil(level)
    }
    
    // MARK: - Round-trip Tests
    
    func testRoundTrip() throws {
        let levels: [SentryLog.Level] = [.trace, .debug, .info, .warn, .error, .fatal]
        
        for original in levels {
            
            let data = try JSONEncoder().encode(original)
            let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryLog.Level?)
            
            XCTAssertEqual(decoded, original)
        }
    }
    
    // MARK: - Array Tests
    
    func testEncodeArrayOfLogLevels() throws {
        let levels: [SentryLog.Level] = [.trace, .debug, .info, .warn, .error, .fatal]
        
        let data = try JSONEncoder().encode(levels)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "[\"trace\",\"debug\",\"info\",\"warn\",\"error\",\"fatal\"]")
    }
    
    func testDecodeArrayOfLogLevels() throws {
        let jsonData = Data("[\"trace\",\"debug\",\"info\",\"warn\",\"error\",\"fatal\"]".utf8)
        
        let levels = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as [SentryLog.Level]?)
        
        XCTAssertEqual(levels, [.trace, .debug, .info, .warn, .error, .fatal])
    }
    
    func testDecodeArrayWithInvalidLevel_ReturnsNil() {
        let jsonData = Data("[\"trace\",\"invalid\",\"debug\"]".utf8)
        
        let levels = decodeFromJSONData(jsonData: jsonData) as [SentryLog.Level]?
        
        XCTAssertNil(levels)
    }
    
    // MARK: - Dictionary Tests
    
    func testEncodeLogLevelInDictionary() throws {
        let dict = ["level": SentryLog.Level.error]
        
        let data = try JSONEncoder().encode(dict)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "{\"level\":\"error\"}")
    }
    
    func testDecodeLogLevelFromDictionary() throws {
        let jsonData = Data("{\"level\":\"warn\"}".utf8)
        
        let dict = try XCTUnwrap(decodeFromJSONData(jsonData: jsonData) as [String: SentryLog.Level]?)
        
        XCTAssertEqual(dict["level"], .warn)
    }
    
    // MARK: - Value Property Tests
    
    func testValuePropertyMatchesEncoding() throws {
        let levels: [SentryLog.Level] = [.trace, .debug, .info, .warn, .error, .fatal]
        
        for level in levels {
            let data = try JSONEncoder().encode(level)
            let jsonString = String(data: data, encoding: .utf8)
            let expectedString = "\"\(level.value)\""
            
            XCTAssertEqual(jsonString, expectedString, "Failed for level: \(level)")
        }
    }
    
    // MARK: - Severity Number Tests
    
    func testSeverityNumberTrace() {
        let level = SentryLog.Level.trace
        
        XCTAssertEqual(level.toSeverityNumber(), 1)
    }
    
    func testSeverityNumberDebug() {
        let level = SentryLog.Level.debug
        
        XCTAssertEqual(level.toSeverityNumber(), 5)
    }
    
    func testSeverityNumberInfo() {
        let level = SentryLog.Level.info
        
        XCTAssertEqual(level.toSeverityNumber(), 9)
    }
    
    func testSeverityNumberWarn() {
        let level = SentryLog.Level.warn
        
        XCTAssertEqual(level.toSeverityNumber(), 13)
    }
    
    func testSeverityNumberError() {
        let level = SentryLog.Level.error
        
        XCTAssertEqual(level.toSeverityNumber(), 17)
    }
    
    func testSeverityNumberFatal() {
        let level = SentryLog.Level.fatal
        
        XCTAssertEqual(level.toSeverityNumber(), 21)
    }
}
