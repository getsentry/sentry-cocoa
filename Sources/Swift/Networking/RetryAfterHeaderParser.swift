import Foundation

/// Parses value of HTTP header "Retry-After" which in most cases is sent in
/// combination with HTTP status 429 Too Many Requests.
///
/// For more details see: https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.37
@objc(SentryRetryAfterHeaderParser) @_spi(Private)
public final class RetryAfterHeaderParser: NSObject {

    private let httpDateParser: HttpDateParser
    private let currentDateProvider: SentryCurrentDateProvider

    @objc
    public init(httpDateParser: HttpDateParser, currentDateProvider: SentryCurrentDateProvider) {
        self.httpDateParser = httpDateParser
        self.currentDateProvider = currentDateProvider
        super.init()
    }

    /// Parses the HTTP header into a NSDate.
    /// - Parameter retryAfterHeader: The header value.
    /// - Returns: NSDate representation of Retry-After. If the date can't be parsed nil is returned.
    @objc
    public func parse(_ retryAfterHeader: String?) -> Date? {
        guard let retryAfterHeader = retryAfterHeader, !retryAfterHeader.isEmpty else {
            return nil
        }

        // Casting to NSString allows us to obtain an integer value even if the string is invalid, contains decimals
        // or random text
        let retryAfterSeconds = NSString(string: retryAfterHeader).integerValue
        if retryAfterSeconds != 0 {
            return currentDateProvider.date().addingTimeInterval(TimeInterval(retryAfterSeconds))
        }

        // parsing as double/seconds failed, try to parse as date
        let retryAfterDate = httpDateParser.date(from: retryAfterHeader)

        return retryAfterDate
    }
}
