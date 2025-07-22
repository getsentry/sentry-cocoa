@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class MutableSentryLogLevelTests: XCTestCase {
    
    // MARK: - MutableSentryLogLevel Tests
    
    func testMutableSentryLogLevel_FromLevel_AllCases() {
        let testCases: [(SentryLog.Level, MutableSentryLogLevel)] = [
            (.trace, .trace),
            (.debug, .debug),
            (.info, .info),
            (.warn, .warn),
            (.error, .error),
            (.fatal, .fatal)
        ]
        
        for (swiftLevel, expectedMutableLevel) in testCases {
            let actualMutableLevel = MutableSentryLogLevel.from(swiftLevel)
            XCTAssertEqual(actualMutableLevel, expectedMutableLevel,
                          "Converting \(swiftLevel) should result in \(expectedMutableLevel)")
        }
    }
    
    func testMutableSentryLogLevel_ToLevel_AllCases() {
        let testCases: [(MutableSentryLogLevel, SentryLog.Level)] = [
            (.trace, .trace),
            (.debug, .debug),
            (.info, .info),
            (.warn, .warn),
            (.error, .error),
            (.fatal, .fatal)
        ]
        
        for (mutableLevel, expectedSwiftLevel) in testCases {
            let actualSwiftLevel = mutableLevel.toLevel()
            XCTAssertEqual(actualSwiftLevel, expectedSwiftLevel,
                          "Converting \(mutableLevel) should result in \(expectedSwiftLevel)")
        }
    }
}
