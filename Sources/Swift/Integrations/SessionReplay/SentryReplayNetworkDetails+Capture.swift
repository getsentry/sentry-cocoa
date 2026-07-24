import Foundation

extension SentryReplayNetworkDetails {
    /// Sets request details from raw body data.
    @objc
    public func setRequest(
        size: NSNumber?,
        bodyData: Data?,
        contentType: String?,
        allHeaders: [String: Any]?,
        configuredHeaders: [String]?
    ) {
        let headers = Self.extractHeaders(from: allHeaders, matching: configuredHeaders)
#if SDK_V10
        let sanitizedHeaders = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .denyList()
        )
        self.request = Detail(
            size: size,
            body: bodyData.flatMap { Body(data: $0, contentType: contentType) },
            headers: sanitizedHeaders.headers,
            cookies: sanitizedHeaders.cookies
        )
#else
        self.request = Detail(
            size: size,
            body: bodyData.flatMap { Body(data: $0, contentType: contentType) },
            headers: headers
        )
#endif // SDK_V10
    }


    /// Sets response details from raw body data.
    @objc
    public func setResponse(
        statusCode: Int,
        size: NSNumber?,
        bodyData: Data?,
        contentType: String?,
        allHeaders: [String: Any]?,
        configuredHeaders: [String]?
    ) {
        self.statusCode = NSNumber(value: statusCode)
        let headers = Self.extractHeaders(from: allHeaders, matching: configuredHeaders)
#if SDK_V10
        let sanitizedHeaders = HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .denyList()
        )
        self.response = Detail(
            size: size,
            body: bodyData.flatMap { Body(data: $0, contentType: contentType) },
            headers: sanitizedHeaders.headers,
            cookies: sanitizedHeaders.cookies
        )
#else
        self.response = Detail(
            size: size,
            body: bodyData.flatMap { Body(data: $0, contentType: contentType) },
            headers: headers
        )
#endif // SDK_V10
    }


    static func extractHeaders(
        from sourceHeaders: [String: Any]?,
        matching configuredHeaders: [String]?
    ) -> [String: String] {
        guard let sourceHeaders, let configuredHeaders else { return [:] }

        var extracted = [String: String]()
        for configured in configuredHeaders {
            let lowered = configured.lowercased()
            for (key, value) in sourceHeaders where key.lowercased() == lowered {
                extracted[key] = (value as? String) ?? "\(value)"
                break
            }
        }
        return extracted
    }


    /// Serializes to dictionary for inclusion in breadcrumb data.
    @objc public func serialize() -> [String: Any] {
        var result = [String: Any]()
        if let method { result["method"] = method }
        if let statusCode { result["statusCode"] = statusCode }
        if let requestBodySize { result["requestBodySize"] = requestBodySize }
        if let responseBodySize { result["responseBodySize"] = responseBodySize }
        if let request { result["request"] = request.serialize() }
        if let response { result["response"] = response.serialize() }
        return result
    }
}
