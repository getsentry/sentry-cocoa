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
        if let rateLimitsHeader = response.value(forHTTPHeaderFieldCaseInsensitive: "x-sentry-rate-limits") {
            let limits = rateLimitParser.parse(rateLimitsHeader)

            for (categoryAsNumber, date) in limits {
                let category = sentryDataCategoryForNSUInteger(categoryAsNumber)
                updateRateLimit(category, withDate: date)
            }
        } else if response.statusCode == 429 {
            let retryAfterHeaderDate = retryAfterHeaderParser.parse(
                response.value(forHTTPHeaderFieldCaseInsensitive: "retry-after")
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

// `internal` (not `private`) so the fallback can be unit-tested; `#available` makes it unreachable
// on the OS versions our tests run on.
extension HTTPURLResponse {
    /// Reads a header case-insensitively. HTTP field names are case-insensitive (RFC 9110, 5.1) and
    /// HTTP/2 (RFC 9113, 8.2.1) and HTTP/3 (RFC 9114, 4.2) send them lowercased, so pass the
    /// lowercase name. `value(forHTTPHeaderField:)` is only available on macOS 10.15+.
    func value(forHTTPHeaderFieldCaseInsensitive name: String) -> String? {
        if #available(macOS 10.15, *) {
            return value(forHTTPHeaderField: name)
        }
        return sentryCaseInsensitiveHeaderValue(forName: name)
    }

    /// Pre-macOS-10.15 fallback: `allHeaderFields` subscripting is case-sensitive. Try the name as
    /// passed, then its lowercase form (HTTP/2, HTTP/3), then the conventional capitalized casing
    /// (HTTP/1.1). This resolves the header whether the caller or the server used lowercase or the
    /// conventional casing.
    /// This is an extra method so it can be unit tested.
    func sentryCaseInsensitiveHeaderValue(forName name: String) -> String? {
        return allHeaderFields[name] as? String
            ?? allHeaderFields[name.lowercased()] as? String
            ?? allHeaderFields[name.capitalized] as? String
    }
}
// swiftlint:enable missing_docs
