// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

/// Parses HTTP responses from the Sentry server for rate limits and stores them
/// in memory. The server can communicate a rate limit either through the 429
/// status code with a "Retry-After" header or through any response with a custom
/// "X-Sentry-Rate-Limits" header. This class is thread safe.
@objc(SentryDefaultRateLimits) @_spi(Private)
public final class DefaultRateLimits: NSObject, RateLimits {

    private let rateLimits: ConcurrentRateLimitsDictionary
    private let retryAfterHeaderParser: RetryAfterHeaderParser
    private let rateLimitParser: RateLimitParser
    private let currentDateProvider: SentryCurrentDateProvider
    private let dateUtil: SentryDateUtil

    @objc
    public init(
        retryAfterHeaderParser: RetryAfterHeaderParser,
        andRateLimitParser rateLimitParser: RateLimitParser,
        currentDateProvider: SentryCurrentDateProvider
    ) {
        self.rateLimits = ConcurrentRateLimitsDictionary()
        self.retryAfterHeaderParser = retryAfterHeaderParser
        self.rateLimitParser = rateLimitParser
        self.currentDateProvider = currentDateProvider
        self.dateUtil = SentryDateUtil(currentDateProvider: currentDateProvider)
        super.init()
    }

    /// `category: UInt` is the unsigned integer representation for SentryDataCategory since we cannot expose
    /// functions written in Swift.
    @objc
    public func isRateLimitActive(_ category: UInt) -> Bool {
        let categoryAsEnum = sentryDataCategoryForNSUInteger(category)
        let categoryDate = rateLimits.getRateLimit(for: categoryAsEnum)
        let allCategoriesDate = rateLimits.getRateLimit(for: .all)

        let isActiveForCategory = dateUtil.isInFuture(categoryDate)
        let isActiveForAllCategories = dateUtil.isInFuture(allCategoriesDate)

        return isActiveForCategory || isActiveForAllCategories
    }

    @objc
    public func update(_ response: HTTPURLResponse) {
        if let rateLimitsHeader = response.sentryHeaderValue(forName: "X-Sentry-Rate-Limits") {
            let limits = rateLimitParser.parse(rateLimitsHeader)

            for (categoryAsNumber, date) in limits {
                let category = sentryDataCategoryForNSUInteger(categoryAsNumber)
                updateRateLimit(category, withDate: date)
            }
        } else if response.statusCode == 429 {
            let retryAfterHeaderDate = retryAfterHeaderParser.parse(
                response.sentryHeaderValue(forName: "Retry-After")
            ) ?? currentDateProvider.date().addingTimeInterval(60)

            updateRateLimit(.all, withDate: retryAfterHeaderDate)
        }
    }

    private func updateRateLimit(_ category: SentryDataCategory, withDate newDate: Date) {
        let existingDate = rateLimits.getRateLimit(for: category)
        guard let longerRateLimitDate = SentryDateUtil.getMaximumDate(existingDate, andOther: newDate) else {
            return
        }
        rateLimits.addRateLimit(category, validUntil: longerRateLimitDate)
    }
}

private extension HTTPURLResponse {
    /// Reads an HTTP response header case-insensitively.
    ///
    /// `allHeaderFields` is a case-sensitive dictionary. Over HTTP/2 (RFC 7540) header field
    /// names are transmitted in lowercase, and recent Apple OS versions no longer canonicalize
    /// custom (non-standard) header names back to their conventional casing. So a direct
    /// `allHeaderFields["X-Sentry-Rate-Limits"]` lookup misses the lowercase
    /// `x-sentry-rate-limits` key the server actually sends, which previously caused the SDK to
    /// treat a category-scoped rate limit as a rate limit for all categories.
    /// See https://github.com/getsentry/sentry-cocoa/issues/8322
    ///
    /// `value(forHTTPHeaderField:)` performs the lookup case-insensitively but is only available
    /// on macOS 10.15+, so below that we use the case-sensitive fallback in
    /// `sentryCaseSensitiveHeaderValue(forName:)`.
    func sentryHeaderValue(forName name: String) -> String? {
        if #available(macOS 10.15, *) {
            return value(forHTTPHeaderField: name)
        }

        return sentryCaseSensitiveHeaderValue(forName: name)
    }
}

extension HTTPURLResponse {
    /// Case-sensitive header lookup used as the pre-macOS-10.15 fallback for
    /// `sentryHeaderValue(forName:)`. It tries the lowercase (HTTP/2) key first, then relay's
    /// canonical casing. Any other casing is not handled, which is an acceptable tradeoff: we're
    /// dropping macOS < 12 support in August 2026 with the move to Xcode 27, so this fallback is
    /// short-lived.
    ///
    /// This lives in its own `internal` extension (rather than the `private` one above) purely so
    /// it can be unit-tested on all platforms, since the `#available(macOS 10.15, *)` branch makes
    /// it unreachable on the OS versions our tests actually run on.
    func sentryCaseSensitiveHeaderValue(forName name: String) -> String? {
        return allHeaderFields[name.lowercased()] as? String
            ?? allHeaderFields[name] as? String
    }
}
// swiftlint:enable missing_docs
