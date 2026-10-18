#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
@_spi(Private) import SentryTestUtils
import _SentryPrivate
import XCTest

final class SentryTestHelperModuleTests: XCTestCase {
    func testExceptionCatcher_whenExceptionRaised_shouldReturnException() {
        // -- Arrange --
        let exception = NSException(name: .invalidArgumentException, reason: "test")

        // -- Act --
        let caught = ExceptionCatcher.try { exception.raise() }

        // -- Assert --
        XCTAssertTrue(caught === exception)
    }

    func testExceptionCatcher_whenBlockSucceeds_shouldReturnNil() {
        // -- Arrange --
        var called = false

        // -- Act --
        let caught = ExceptionCatcher.try { called = true }

        // -- Assert --
        XCTAssertTrue(called)
        XCTAssertNil(caught)
    }

    func testUnzip_whenGivenGzipData_shouldDecompress() throws {
        // -- Arrange --
        let compressed = try XCTUnwrap(Data(base64Encoded: "H4sIAAAAAAACE0vNK0vNyS9IBQBoeJWKCAAAAA=="))

        // -- Act --
        let data = sentry_unzippedData(compressed)

        // -- Assert --
        XCTAssertEqual(data, Data("envelope".utf8))
    }

    func testRuntimeWrapper_whenImported_shouldConformToSwiftProtocol() {
        // -- Arrange --
        let wrapper: SentryObjCRuntimeWrapper = SentryTestObjCRuntimeWrapper()

        // -- Act --
        let imageName = wrapper.classGetImageName(SentryTestHelperModuleTests.self)

        // -- Assert --
        XCTAssertNil(imageName)
    }

    #if !SDK_V10
    func testCrashScopeHelper_whenImported_shouldForwardSwiftProtocolCalls() throws {
        // -- Arrange --
        let observer: SentryScopeObserver = SentryCrashScopeHelper.getScopeObserver(withMaxBreacdrumb: 10)
        defer { sentrycrash_scopesync_reset() }

        // -- Act --
        observer.setEnvironment("test")

        // -- Assert --
        let environment = try XCTUnwrap(sentrycrash_scopesync_getScope().pointee.environment)
        XCTAssertEqual(String(cString: environment), "\"test\"")
    }
    #endif

    func testURLSessionTaskMock_whenStateChanges_shouldExposeStateAndRequest() throws {
        // -- Arrange --
        let request = URLRequest(url: try XCTUnwrap(URL(string: "https://example.com")))
        let task = URLSessionDataTaskMock(request: request)

        // -- Act --
        task.state = .running

        // -- Assert --
        XCTAssertEqual(task.state, .running)
        XCTAssertEqual(task.currentRequest, request)
    }

    // These compare distinct instances so missing category objects in a static library fail.
    func testMessageEquality_whenValuesMatch_shouldCompareByValue() {
        // -- Arrange --
        let first = SentryMessage(formatted: "message")
        let second = SentryMessage(formatted: "message")
        let different = SentryMessage(formatted: "different")

        // -- Act / Assert --
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, different)
    }

    func testAttachmentEquality_whenValuesMatch_shouldCompareByValue() {
        // -- Arrange --
        let first = Attachment(data: Data("data".utf8), filename: "first.txt")
        let second = Attachment(data: Data("data".utf8), filename: "first.txt")
        let different = Attachment(data: Data("data".utf8), filename: "second.txt")

        // -- Act / Assert --
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, different)
    }

    func testAppStateEquality_whenValuesMatch_shouldCompareByValue() {
        // -- Arrange --
        let timestamp = Date(timeIntervalSince1970: 1)
        let first = SentryAppState(releaseName: "release", osVersion: "1", vendorId: nil, isDebugging: false, systemBootTimestamp: timestamp)
        let second = SentryAppState(releaseName: "release", osVersion: "1", vendorId: nil, isDebugging: false, systemBootTimestamp: timestamp)

        // -- Act / Assert --
        XCTAssertEqual(first, second)
        second.isActive = true
        first.isActive = false
        XCTAssertNotEqual(first, second)
    }

    func testScopeEquality_whenValuesMatch_shouldCompareByValue() {
        // -- Arrange --
        let first = Scope()
        let second = Scope()
        first.setTag(value: "value", key: "key")
        second.setTag(value: "value", key: "key")

        // -- Act / Assert --
        XCTAssertEqual(first, second)
        second.setTag(value: "different", key: "key")
        XCTAssertNotEqual(first, second)
    }
}
