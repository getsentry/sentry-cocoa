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

    /// Reads a header case-insensitively.
    /// Since HTTP/2 HTTP field names are case-insensitive including HTTP headers; see HTTP/2 (RFC 9113, 8.2.1) and HTTP/3 (RFC 9114, 4.2):
    /// - https://www.rfc-editor.org/rfc/rfc9113#section-8.2.1
    /// - https://www.rfc-editor.org/rfc/rfc9114#section-4.2
    func value(forHTTPHeaderFieldCaseInsensitive name: String) -> String? {
        if #available(macOS 10.15, *) {
            // `value(forHTTPHeaderField:)` retrieves the header case-insensitively.
            return value(forHTTPHeaderField: name)
        }
        return sentryCaseInsensitiveHeaderValue(forName: name)
    }

    /// Pre-macOS-10.15 fallback is an extra method so it can be unit tested. We plan on bumping to macOS 12
    /// in August 2026, so we don't use this implementation for all platforms.
    ///
    /// `allHeaderFields` subscripting is case-sensitive, so we scan all keys and compare them
    /// case-insensitively against `name`. This is O(n), which is acceptable for the small number of
    /// response headers.
    func sentryCaseInsensitiveHeaderValue(forName name: String) -> String? {
        let lowercasedName = name.lowercased()
        // The linter forbids `allHeaderFields` because its subscript is case-sensitive, and it points
        // callers to `value(forHTTPHeaderField:)`. That API is only available on macOS 10.15+, so this
        // pre-10.15 fallback has to iterate `allHeaderFields` instead. The case-sensitivity bug the
        // linter guards against doesn't apply here: we don't subscript, we compare every key against
        // `name` with both sides lowercased.
        // swiftlint:disable avoid_all_header_fields
        for (key, value) in allHeaderFields {
            if let key = key as? String, key.lowercased() == lowercasedName {
                return value as? String
            }
        }
        // swiftlint:enable avoid_all_header_fields
        return nil
    }
}
// swiftlint:enable missing_docs
