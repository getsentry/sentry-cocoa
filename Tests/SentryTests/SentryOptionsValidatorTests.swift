@testable import Sentry
import XCTest

class SentryOptionsValidatorTests: XCTestCase {

    private class Fixture {
        let logOutput: TestLogOutput

        init() {
            logOutput = TestLogOutput()
        }

        func getSut() {
            SentryLog.setLogOutput(logOutput)
            SentryLog.configureLog(true, diagnosticLevel: .fatal)
        }

        func getLoggedMessages() -> [String] {
            logOutput.loggedMessages
        }

        func getLongestValidPath() -> String {
            let validPathSegment = "/" + Array(repeating: "a", count: 127)
                .joined() // 128 characters
            let validPath = Array(repeating: validPathSegment, count: 6)
                .joined() // 6 * 128 = 768 characters

            return validPath
        }

        func getLongestValidPathComponent() -> String {
            return Array(repeating: "a", count: 255)
                .joined()
        }
    }

    private var fixture: Fixture!

    override func setUp() {
        super.setUp()

        fixture = Fixture()
    }

    private func assertLoggedMessage(
        expectedMessage: String,
        level: SentryLevel,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let log = fixture.getLoggedMessages().first
        XCTAssertNotNil(log)
        XCTAssertTrue(log!.contains(
            "[Sentry] [\(level.description)]"
        ), "Log message does not contain expected level.", file: file, line: line)
        XCTAssertTrue(log!.contains(expectedMessage), "Log message does not contain expected message.", file: file, line: line)
    }

    func testValidateOptions_defaultOptionsValid_shouldNotLogValidationErrors() {
        // -- Arrange --
        fixture.getSut()
        let options = Options()

        // -- Act --
        SentryOptionsValidator.validate(options: options)

        // -- Assert --
        let log = fixture.getLoggedMessages().first
        XCTAssertNil(log)
    }

    func testValidateOptions_invalidCacheDirectoryPath_shouldLog() {
        // -- Arrange --
        fixture.getSut()
        let options = Options()
        options.cacheDirectoryPath = Array(repeating: "a", count: Int(PATH_MAX))
            .joined()

        // -- Act --
        SentryOptionsValidator.validate(options: options)

        // -- Assert --
        assertLoggedMessage(
            expectedMessage: "The configured cache directory path looks invalid, the SDK might not be able to write reports to disk:",
            level: SentryLevel.fatal
        )
    }

    func testIsCacheDirectoryPathValid_argumentNotString_isNotValid() {
        // -- Arrange --
        fixture.getSut()
        let path = 1

        // -- Act --
        let result = SentryOptionsValidator.isCacheDirectoryPathValid(path: path)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testIsCacheDirectoryPathValid_pathEmpty_isValid() {
        // -- Arrange --
        fixture.getSut()
        let path = ""

        // -- Act --
        let result = SentryOptionsValidator.isCacheDirectoryPathValid(path: path)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsCacheDirectoryPathValid_rootPath_isValid() {
        // -- Arrange --
        fixture.getSut()
        let path = "/"

        // -- Act --
        let result = SentryOptionsValidator.isCacheDirectoryPathValid(path: path)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsCacheDirectoryPathValid_pathComponentLengthBelowLimit_isValid() {
        // -- Arrange --
        fixture.getSut()
        let longestValidPathComponent = fixture.getLongestValidPathComponent()
        let component = String(longestValidPathComponent.dropLast())
        let path = "/tmp/" + component + "/file"

        // smoke test of generated string
        XCTAssertEqual(path.count, 5 + 255 - 1 + 5)

        // -- Act --
        let result = SentryOptionsValidator.isCacheDirectoryPathValid(path: path)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsCacheDirectoryPathValid_pathComponentLengthAtLimit_isValid() {
        // -- Arrange --
        fixture.getSut()
        let component = fixture.getLongestValidPathComponent()
        let path = "/tmp/" + component + "/file"

        // smoke test of generated string
        XCTAssertEqual(path.count, 5 + 255 + 5)

        // -- Act --
        let result = SentryOptionsValidator.isCacheDirectoryPathValid(path: path)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsCacheDirectoryPathValid_pathComponentLengthOverLimit_isNotValid() {
        // -- Arrange --
        fixture.getSut()
        let longestValidPathComponent = fixture.getLongestValidPathComponent()
        let component = longestValidPathComponent + "B"
        let path = "/tmp/" + component + "/file"

        // smoke test of generated string
        XCTAssertEqual(path.count, 5 + 255 + 1 + 5)

        // -- Act --
        let result = SentryOptionsValidator.isCacheDirectoryPathValid(path: path)

        // -- Assert --
        XCTAssertFalse(result)
    }

    func testIsCacheDirectoryPathValid_pathLengthBelowLimitWithReservation_returnsFalse() {
        // -- Arrange --
        fixture.getSut()
        let longestValidPath = fixture.getLongestValidPath()
        let path = String(longestValidPath.dropLast())

        // smoke test of generated string
        XCTAssertEqual(path.count, 1_024 - 256 - 1)

        // -- Act --
        let result = SentryOptionsValidator.isCacheDirectoryPathValid(path: path)

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsCacheDirectoryPathValid_pathLengthAtLimitWithReservation_isValid() {
        // -- Arrange --
        fixture.getSut()
        let path = fixture.getLongestValidPath()

        // smoke test of generated string
        XCTAssertEqual(path.count, 1_024 - 256)

        // -- Act --
        let result = SentryOptionsValidator.isCacheDirectoryPathValid(
            path: path
        )

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testIsCacheDirectoryPathValid_pathLengthOverLimitWithResetvation_isNotValid() {
        // -- Arrange --
        fixture.getSut()
        let longestValidPath = fixture.getLongestValidPath()
        let path = longestValidPath + "B"

        // smoke test of generated string
        XCTAssertEqual(path.count, 1_024 - 256 + 1)
        // -- Act --
        let result = SentryOptionsValidator.isCacheDirectoryPathValid(
            path: path
        )

        // -- Assert --
        XCTAssertFalse(result)
    }
}
