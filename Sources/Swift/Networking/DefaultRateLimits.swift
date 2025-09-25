@_implementationOnly import _SentryPrivate
import Foundation

/**
 Parses HTTP responses from the Sentry server for rate limits and stores them
 in memory. The server can communicate a rate limit either through the 429
 status code with a "Retry-After" header or through any response with a custom
 "X-Sentry-Rate-Limits" header. This class is thread safe.
*/
@objc(SentryDefaultRateLimits) @_spi(Private)
public final class DefaultRateLimits: NSObject, RateLimits {

    private let rateLimits: SentryConcurrentRateLimitsDictionary
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
        self.rateLimits = SentryConcurrentRateLimitsDictionary()
        self.retryAfterHeaderParser = retryAfterHeaderParser
        self.rateLimitParser = rateLimitParser
        self.currentDateProvider = currentDateProvider
        self.dateUtil = SentryDateUtil(currentDateProvider: currentDateProvider)
        super.init()
    }

    // `category: UInt` is the unsigned integer representation for SentryDataCategory since we cannot expose
    // functions written in Swift.
    @objc
    public func isRateLimitActive(_ category: UInt) -> Bool {
        let categoryAsEnum = sentryDataCategoryForNSUInteger(category)
        let categoryDate = rateLimits.getRateLimit(for: categoryAsEnum)
        let allCategoriesDate = rateLimits.getRateLimit(for: .all)

        let isActiveForCategory = dateUtil.is(inFuture: categoryDate)
        let isActiveForAllCategories = dateUtil.is(inFuture: allCategoriesDate)

        return isActiveForCategory || isActiveForAllCategories
    }

    @objc
    public func update(_ response: HTTPURLResponse) {
        if let rateLimitsHeader = response.allHeaderFields["X-Sentry-Rate-Limits"] as? String {
            let limits = rateLimitParser.parse(rateLimitsHeader)

            for (categoryAsNumber, date) in limits {
                let category = sentryDataCategoryForNSUInteger(categoryAsNumber.uintValue)
                updateRateLimit(category, withDate: date)
            }
        } else if response.statusCode == 429 {
            var retryAfterHeaderDate = retryAfterHeaderParser.parse(
                response.allHeaderFields["Retry-After"] as? String
            )

            if retryAfterHeaderDate == nil {
                // parsing failed use default value
                retryAfterHeaderDate = currentDateProvider.date().addingTimeInterval(60)
            }

            guard let retryAfterHeaderDate = retryAfterHeaderDate else {
                return
            }
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
