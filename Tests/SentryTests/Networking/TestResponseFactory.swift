struct TestResponseFactory {
    
    static func createRetryAfterResponse(headerValue: String) -> HTTPURLResponse {
        return HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 429,
            httpVersion: "1.1",
            headerFields: ["Retry-After": headerValue])!
    }
    
    static func createRateLimitResponse(headerValue: String) -> HTTPURLResponse {
        return HTTPURLResponse.init(
            url: URL.init(fileURLWithPath: ""),
            statusCode: 200,
            httpVersion: "1.1",
            headerFields: ["X-Sentry-Rate-Limits": headerValue])!
    }
}
