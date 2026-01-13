@_implementationOnly import _SentryPrivate
import Foundation

/** Parses the custom X-Sentry-Rate-Limits header.

 This header exists of a multiple quotaLimits separated by ",".
 Each quotaLimit exists of retry_after:categories:scope.
 retry_after: seconds until the rate limit expires.
 categories: semicolon separated list of categories. If empty, this limit
 applies to all categories. scope: This can be ignored by SDKs.
 */
@objc(SentryRateLimitParser) @_spi(Private)
public final class RateLimitParser: NSObject {

    private let currentDateProvider: SentryCurrentDateProvider

    @objc
    public init(currentDateProvider: SentryCurrentDateProvider) {
        self.currentDateProvider = currentDateProvider
        super.init()
    }

    @objc
    public func parse(_ header: String) -> [UInt: Date] {
        guard !header.isEmpty else {
            return [:]
        }

        var rateLimits: [UInt: Date] = [:]

        // The header might contain whitespaces and they must be ignored.
        let headerNoWhitespaces = removeAllWhitespaces(header)

        // Each quotaLimit exists of retryAfter:categories:scope. The scope is
        // ignored here as it can be ignored by SDKs.
        for quota in headerNoWhitespaces.components(separatedBy: ",") {
            let parameters = quota.components(separatedBy: ":")

            guard parameters.count >= 2,
                let rateLimitInSeconds = parseRateLimitSeconds(parameters[0]),
                  rateLimitInSeconds.intValue > 0 else {
                continue
            }

            for categoryNumber in parseCategories(parameters[1]) {
                let dataCategory = sentryDataCategoryForNSUInteger(categoryNumber)

                // Namespaces should only be available for MetricBucket
                if dataCategory == .metricBucket && parameters.count > 4 {
                    let namespacesAsString = parameters[4]
                    let namespaces = namespacesAsString.components(separatedBy: ";")

                    if namespacesAsString.isEmpty || namespaces.contains("custom") {
                        rateLimits[categoryNumber] = getLongerRateLimit(
                            existingRateLimit: rateLimits[categoryNumber],
                            rateLimitInSeconds: rateLimitInSeconds
                        )
                    }
                } else {
                    rateLimits[categoryNumber] = getLongerRateLimit(
                        existingRateLimit: rateLimits[categoryNumber],
                        rateLimitInSeconds: rateLimitInSeconds
                    )
                }
            }
        }

        return rateLimits
    }

    private func removeAllWhitespaces(_ string: String) -> String {
        let words = string.components(separatedBy: .whitespacesAndNewlines)
        return words.joined()
    }

    private func parseRateLimitSeconds(_ string: String) -> NSNumber? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        return numberFormatter.number(from: string)
    }

    private func parseCategories(_ categoriesAsString: String) -> [UInt] {
        // The categories are a semicolon separated list. If this parameter is empty
        // it stands for all categories. componentsSeparatedByString returns one
        // category even if this parameter is empty.
        var categories: [UInt] = []

        for categoryAsString in categoriesAsString.components(separatedBy: ";") {
            let category = sentryDataCategoryForString(categoryAsString)

            // Unknown categories must be ignored. UserFeedback is not listed for rate limits, see
            // https://develop.sentry.dev/sdk/rate-limiting/#definitions
            if category != .unknown && category != .userFeedback {
                categories.append(category.rawValue)
            }
        }

        return categories
    }

    private func getLongerRateLimit(
        existingRateLimit: Date?,
        rateLimitInSeconds: NSNumber
    ) -> Date {
        let newDate = currentDateProvider.date().addingTimeInterval(rateLimitInSeconds.doubleValue)
        return SentryDateUtil.getMaximumDate(newDate, andOther: existingRateLimit) ?? newDate
    }
}
