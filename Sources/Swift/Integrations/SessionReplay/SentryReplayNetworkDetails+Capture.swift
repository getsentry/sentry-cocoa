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
        let sanitizedHeaders = Self.sanitizeHeaders(headers)
        let request = Detail(
            size: size,
            body: bodyData.flatMap { Body(data: $0, contentType: contentType) },
            headers: sanitizedHeaders.headers,
            cookies: sanitizedHeaders.cookies
        )
#else
        let request = Detail(
            size: size,
            body: bodyData.flatMap { Body(data: $0, contentType: contentType) },
            headers: headers
        )
#endif // SDK_V10
        state.withLockIfAvailable { $0.request = request }
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
        let headers = Self.extractHeaders(from: allHeaders, matching: configuredHeaders)
#if SDK_V10
        let sanitizedHeaders = Self.sanitizeHeaders(headers)
        let response = Detail(
            size: size,
            body: bodyData.flatMap { Body(data: $0, contentType: contentType) },
            headers: sanitizedHeaders.headers,
            cookies: sanitizedHeaders.cookies
        )
#else
        let response = Detail(
            size: size,
            body: bodyData.flatMap { Body(data: $0, contentType: contentType) },
            headers: headers
        )
#endif // SDK_V10
        state.withLockIfAvailable {
            $0.statusCode = NSNumber(value: statusCode)
            $0.response = response
        }
    }

#if SDK_V10
    /// Applies the built-in sensitive denylist to headers Session Replay is about to capture.
    ///
    /// Session Replay deliberately does **not** read the header and cookie behaviors from
    /// `SentryOptions.dataCollection`. Per the data collection spec, Replay is not gated by
    /// `dataCollection` (or its predecessor `sendDefaultPii`): it is a privacy-sensitive feature with
    /// its own opt-in privacy model — masking everything by default — which is the opposite of the
    /// `dataCollection` opt-out model. Wiring the two together would flip privacy-sensitive defaults
    /// for existing Replay users and blur which layer controls masking. Which headers Replay captures
    /// therefore stays controlled exclusively by `networkRequestHeaders` and `networkResponseHeaders`.
    ///
    /// The denylist is still applied on top of that user selection, because sensitive values must
    /// never be sent in plaintext through automatic instrumentation, regardless of which layer
    /// selected the header. Using `.denyList()` without extra terms keeps the user's explicit
    /// selection intact while scrubbing values whose names match the built-in sensitive terms.
    ///
    /// See https://develop.sentry.dev/sdk/foundations/client/data-collection/#session-replay
    private static func sanitizeHeaders(_ headers: [String: String]) -> HTTPHeaderSanitizer.SanitizedHeaders {
        HTTPHeaderSanitizer.sanitizeHeaders(
            headers,
            headerBehavior: .denyList(),
            cookieBehavior: .denyList()
        )
    }
#endif // SDK_V10

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
        result["method"] = method
        state.withLockIfAvailable { state in
            result["statusCode"] = state.statusCode
            result["requestBodySize"] = state.request?.size
            result["responseBodySize"] = state.response?.size
            result["request"] = state.request?.serialize()
            result["response"] = state.response?.serialize()
        }
        return result
    }
}
