@testable import Sentry
import Foundation
import XCTest

final class SentrySwizzleMethodURLSessionTaskTests: XCTestCase {

    func testURLSessionTaskResume_shouldDescribeResumeSignature() {
        // -- Act --
        let method = SentrySwizzleMethod<URLSessionTask, Void, Void>
            .urlSessionTaskResume(URLSessionTask.self)

        // -- Assert --
        XCTAssertEqual(method.selector, #selector(URLSessionTask.resume))
        XCTAssertTrue(method.receiver == URLSessionTask.self)
        XCTAssertEqual(method.signature.description, "v@:")
    }

    func testURLSessionTaskResume_whenValidatingPublicMethod_shouldReturnTrue() {
        // -- Act --
        let result = SentryTypedSwizzle.validate(
            in: URLSessionTask.self,
            method: .urlSessionTaskResume(URLSessionTask.self)
        )

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testURLSessionTaskState_shouldDescribeStateSetterSignature() {
        // -- Act --
        let method = SentrySwizzleMethod<SwizzleMethodURLSessionTaskTarget, URLSessionTask.State, Void>
            .urlSessionTaskState(SwizzleMethodURLSessionTaskTarget.self)

        // -- Assert --
        XCTAssertEqual(method.selector, NSSelectorFromString("setState:"))
        XCTAssertTrue(method.receiver == SwizzleMethodURLSessionTaskTarget.self)
        XCTAssertEqual(method.signature.description, "v@:signed-int\(MemoryLayout<Int>.size * 8)")
    }

    func testURLSessionTaskState_whenValidatingMatchingMethod_shouldReturnTrue() {
        // -- Act --
        let result = SentryTypedSwizzle.validate(
            in: SwizzleMethodURLSessionTaskTarget.self,
            method: .urlSessionTaskState(SwizzleMethodURLSessionTaskTarget.self)
        )

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testURLSessionDataTaskWithRequest_shouldDescribeDataTaskSignature() {
        // -- Act --
        let method = SentrySwizzleMethod<URLSession, SentryDataTaskRequestArguments, URLSessionDataTask>
            .urlSessionDataTaskWithRequest(URLSession.self)

        // -- Assert --
        let expectedSelector = #selector(URLSession.dataTask(with:completionHandler:)
            as (URLSession) -> (URLRequest, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask)
        XCTAssertEqual(method.selector, expectedSelector)
        XCTAssertTrue(method.receiver == URLSession.self)
        XCTAssertEqual(method.signature.description, "@@:@@?")
    }

    func testURLSessionDataTaskWithRequest_whenValidatingPublicMethod_shouldReturnTrue() {
        // -- Act --
        let result = SentryTypedSwizzle.validate(
            in: URLSession.self,
            method: .urlSessionDataTaskWithRequest(URLSession.self)
        )

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testURLSessionDataTaskWithURL_shouldDescribeDataTaskSignature() {
        // -- Act --
        let method = SentrySwizzleMethod<URLSession, SentryDataTaskURLArguments, URLSessionDataTask>
            .urlSessionDataTaskWithURL(URLSession.self)

        // -- Assert --
        let expectedSelector = #selector(URLSession.dataTask(with:completionHandler:)
            as (URLSession) -> (URL, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask)
        XCTAssertEqual(method.selector, expectedSelector)
        XCTAssertTrue(method.receiver == URLSession.self)
        XCTAssertEqual(method.signature.description, "@@:@@?")
    }

    func testURLSessionDataTaskWithURL_whenValidatingPublicMethod_shouldReturnTrue() {
        // -- Act --
        let result = SentryTypedSwizzle.validate(
            in: URLSession.self,
            method: .urlSessionDataTaskWithURL(URLSession.self)
        )

        // -- Assert --
        XCTAssertTrue(result)
    }

    func testURLSessionDataTaskDescriptors_shouldBindDifferentSelectors() {
        // -- Arrange --
        let requestMethod = SentrySwizzleMethod<URLSession, SentryDataTaskRequestArguments, URLSessionDataTask>
            .urlSessionDataTaskWithRequest(URLSession.self)
        let urlMethod = SentrySwizzleMethod<URLSession, SentryDataTaskURLArguments, URLSessionDataTask>
            .urlSessionDataTaskWithURL(URLSession.self)

        // -- Assert --
        XCTAssertNotEqual(requestMethod.selector, urlMethod.selector)
        XCTAssertEqual(requestMethod.signature.description, urlMethod.signature.description)
    }

    func testDataTaskCompletionHandler_whenInvoked_shouldForwardAllValues() {
        // -- Arrange --
        let data = Data("body".utf8)
        let response = URLResponse(
            url: URL(string: "https://example.com")!,
            mimeType: "text/plain",
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        let error = NSError(domain: "SentrySwizzleMethodTests", code: 1)
        var receivedData: Data?
        var receivedResponse: URLResponse?
        var receivedError: Error?
        let completionHandler: SentryDataTaskCompletionHandler = { value, response, error in
            receivedData = value
            receivedResponse = response
            receivedError = error
        }

        // -- Act --
        completionHandler(data, response, error)

        // -- Assert --
        XCTAssertEqual(receivedData, data)
        XCTAssertIdentical(receivedResponse, response)
        XCTAssertEqual(receivedError as NSError?, error)
    }
}

private final class SwizzleMethodURLSessionTaskTarget: NSObject {
    @objc dynamic func setState(_ state: URLSessionTask.State) {}
}
