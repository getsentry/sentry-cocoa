import Foundation

#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import XCTest

final class SentryObjCCompatLoggerTests: XCTestCase {

    private class MockDateProvider: NSObject, SentryCurrentDateProvider {
        func date() -> Date { Date(timeIntervalSince1970: 0) }
        func timezoneOffset() -> Int { 0 }
        func systemTime() -> UInt64 { 0 }
        func systemUptime() -> TimeInterval { 0 }
        @objc func getAbsoluteTime() -> UInt64 { 0 }
    }

    private class MockLoggerDelegate: NSObject, SentryLoggerDelegate {
        var capturedLogs: [SentryLog] = []
        func capture(log: SentryLog) {
            capturedLogs.append(log)
        }
    }

    private var delegate: MockLoggerDelegate!
    private var sut: SentryObjCLogger!

    override func setUp() {
        super.setUp()
        delegate = MockLoggerDelegate()
        let logger = SentryLogger(delegate: delegate, dateProvider: MockDateProvider())
        sut = SentryObjCLogger(logger)
    }

    // MARK: - Level forwarding

    func testTrace_shouldForwardAtTraceLevel() {
        // -- Act --
        sut.trace("trace msg")

        // -- Assert --
        XCTAssertEqual(delegate.capturedLogs.count, 1)
        XCTAssertEqual(delegate.capturedLogs[0].level, .trace)
        XCTAssertEqual(delegate.capturedLogs[0].body, "trace msg")
    }

    func testDebug_shouldForwardAtDebugLevel() {
        // -- Act --
        sut.debug("debug msg")

        // -- Assert --
        XCTAssertEqual(delegate.capturedLogs[0].level, .debug)
        XCTAssertEqual(delegate.capturedLogs[0].body, "debug msg")
    }

    func testInfo_shouldForwardAtInfoLevel() {
        // -- Act --
        sut.info("info msg")

        // -- Assert --
        XCTAssertEqual(delegate.capturedLogs[0].level, .info)
        XCTAssertEqual(delegate.capturedLogs[0].body, "info msg")
    }

    func testWarn_shouldForwardAtWarnLevel() {
        // -- Act --
        sut.warn("warn msg")

        // -- Assert --
        XCTAssertEqual(delegate.capturedLogs[0].level, .warn)
        XCTAssertEqual(delegate.capturedLogs[0].body, "warn msg")
    }

    func testError_shouldForwardAtErrorLevel() {
        // -- Act --
        sut.error("error msg")

        // -- Assert --
        XCTAssertEqual(delegate.capturedLogs[0].level, .error)
        XCTAssertEqual(delegate.capturedLogs[0].body, "error msg")
    }

    func testFatal_shouldForwardAtFatalLevel() {
        // -- Act --
        sut.fatal("fatal msg")

        // -- Assert --
        XCTAssertEqual(delegate.capturedLogs[0].level, .fatal)
        XCTAssertEqual(delegate.capturedLogs[0].body, "fatal msg")
    }

    // MARK: - Attribute forwarding

    func testDebug_withAttributes_shouldForwardTypedAttributes() {
        // -- Act --
        sut.debug("msg", attributes: [
            "string_key": "value",
            "int_key": 42,
            "double_key": 3.14,
            "bool_key": true
        ])

        // -- Assert --
        let attrs = delegate.capturedLogs[0].attributes
        XCTAssertEqual(attrs["string_key"]?.type, "string")
        XCTAssertEqual(attrs["string_key"]?.value as? String, "value")
        XCTAssertEqual(attrs["int_key"]?.type, "integer")
        XCTAssertEqual(attrs["int_key"]?.value as? Int, 42)
        XCTAssertEqual(attrs["double_key"]?.type, "double")
        XCTAssertEqual(attrs["double_key"]?.value as? Double, 3.14)
        XCTAssertEqual(attrs["bool_key"]?.type, "boolean")
        XCTAssertEqual(attrs["bool_key"]?.value as? Bool, true)
    }

    func testDebug_withEmptyAttributes_shouldCaptureLog() {
        // -- Act --
        sut.debug("msg", attributes: [:])

        // -- Assert --
        XCTAssertEqual(delegate.capturedLogs.count, 1)
        XCTAssertEqual(delegate.capturedLogs[0].body, "msg")
    }

    // MARK: - Template attribute pass-through

    func testDebug_withTemplateAttributesInDict_shouldPreserveThem() {
        // -- Arrange --
        let attrs: [String: Any] = [
            "sentry.message.template": "User {0} did {1}",
            "sentry.message.parameter.0": "john",
            "sentry.message.parameter.1": 42
        ]

        // -- Act --
        sut.debug("User john did 42", attributes: attrs)

        // -- Assert --
        let log = delegate.capturedLogs[0]
        XCTAssertEqual(log.body, "User john did 42")
        XCTAssertEqual(log.attributes["sentry.message.template"]?.value as? String, "User {0} did {1}")
        XCTAssertEqual(log.attributes["sentry.message.parameter.0"]?.value as? String, "john")
        XCTAssertEqual(log.attributes["sentry.message.parameter.1"]?.value as? Int, 42)
    }

    func testInfo_withTemplateAndUserAttributes_shouldPreserveBoth() {
        // -- Arrange --
        let attrs: [String: Any] = [
            "sentry.message.template": "Count: {0}",
            "sentry.message.parameter.0": 5,
            "source": "test"
        ]

        // -- Act --
        sut.info("Count: 5", attributes: attrs)

        // -- Assert --
        let log = delegate.capturedLogs[0]
        XCTAssertEqual(log.level, .info)
        XCTAssertEqual(log.attributes["sentry.message.template"]?.value as? String, "Count: {0}")
        XCTAssertEqual(log.attributes["sentry.message.parameter.0"]?.value as? Int, 5)
        XCTAssertEqual(log.attributes["source"]?.value as? String, "test")
    }

    // MARK: - Multiple logs

    func testMultipleLogs_shouldCaptureAll() {
        // -- Act --
        sut.trace("1")
        sut.debug("2")
        sut.info("3")
        sut.warn("4")
        sut.error("5")
        sut.fatal("6")

        // -- Assert --
        XCTAssertEqual(delegate.capturedLogs.count, 6)
        XCTAssertEqual(delegate.capturedLogs[0].level, .trace)
        XCTAssertEqual(delegate.capturedLogs[1].level, .debug)
        XCTAssertEqual(delegate.capturedLogs[2].level, .info)
        XCTAssertEqual(delegate.capturedLogs[3].level, .warn)
        XCTAssertEqual(delegate.capturedLogs[4].level, .error)
        XCTAssertEqual(delegate.capturedLogs[5].level, .fatal)
    }
}
