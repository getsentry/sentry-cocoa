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
    
    // MARK: - Array Tests
    
    func testEncodeArrayOfLogLevels() throws {
        let levels: [SentryLog.Level] = [.trace, .debug, .info, .warn, .error, .fatal]
        
        let data = try JSONEncoder().encode(levels)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "[\"trace\",\"debug\",\"info\",\"warn\",\"error\",\"fatal\"]")
    }
    
    // MARK: - Dictionary Tests
    
    func testEncodeLogLevelInDictionary() throws {
        let dict = ["level": SentryLog.Level.error]
        
        let data = try JSONEncoder().encode(dict)
        let jsonString = String(data: data, encoding: .utf8)
        
        XCTAssertEqual(jsonString, "{\"level\":\"error\"}")
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
