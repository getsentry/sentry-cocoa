@_implementationOnly import _SentryPrivate
import Foundation

/// A thread safe wrapper around a dictionary to store rate limits.
final class ConcurrentRateLimitsDictionary: @unchecked Sendable {

    /// Key is the category and value is the valid-until date.
    private var rateLimits = [SentryDataCategory: Date]()
    private let lock = NSLock()

    /// Adds the passed rate limit for the given category.
    /// If a rate limit already exists it is overwritten.
    func addRateLimit(_ category: SentryDataCategory, validUntil date: Date) {
        lock.synchronized {
            rateLimits[category] = date
        }
    }

    /// Returns the date until the rate limit is active.
    func getRateLimit(for category: SentryDataCategory) -> Date? {
        lock.synchronized {
            rateLimits[category]
        }
    }
}
