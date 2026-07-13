import XCTest

struct TestResponseFactory {

    static func createRetryAfterResponse(headerValue: String) throws -> HTTPURLResponse {
        return try createResponse(statusCode: 429, httpVersion: "2.0", headerFields: ["retry-after": headerValue])
    }

    static func createRetryAfterResponseHTTP1_1(headerValue: String) throws -> HTTPURLResponse {
        return try createResponse(statusCode: 429, httpVersion: "1.1", headerFields: ["Retry-After": headerValue])
    }

    static func createRateLimitResponse(headerValue: String) throws -> HTTPURLResponse {
        return try createResponse(statusCode: 200, httpVersion: "2.0", headerFields: ["x-sentry-rate-limits": headerValue])
    }

    static func createRateLimitResponseHTTP1_1(headerValue: String) throws -> HTTPURLResponse {
        return try createResponse(statusCode: 200, httpVersion: "1.1", headerFields: ["X-Sentry-Rate-Limits": headerValue])
    }

    private static func createResponse(statusCode: Int, httpVersion: String, headerFields: [String: String]) throws -> HTTPURLResponse {
        return try XCTUnwrap(HTTPURLResponse(
            url: URL(fileURLWithPath: ""),
            statusCode: statusCode,
            httpVersion: httpVersion,
            headerFields: headerFields))
    }
}
