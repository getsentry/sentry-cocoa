import XCTest

struct TestResponseFactory {
    // The test fails if the responses could not be created
    static func createRetryAfterResponse(headerValue: String) -> HTTPURLResponse {
        let response = HTTPURLResponse(
                url: URL(fileURLWithPath: ""),
                statusCode: 429,
                httpVersion: "1.1",
                headerFields: ["Retry-After": headerValue])
        if response == nil {
            XCTFail("Response could not be created")
        }
        return response!
    }

    static func createRateLimitResponse(headerValue: String) -> HTTPURLResponse {
        let response = HTTPURLResponse(
                url: URL(fileURLWithPath: ""),
                statusCode: 200,
                httpVersion: "1.1",
                headerFields: ["X-Sentry-Rate-Limits": headerValue])
        if response == nil {
            XCTFail("Response could not be created")
        }
        return response!
    }
}
