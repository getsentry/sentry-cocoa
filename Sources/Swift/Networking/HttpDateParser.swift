// swiftlint:disable missing_docs
import Foundation

/**
 * Parses a string in the format of http date to NSDate. For more details see:
 * https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Date.
 * SentryHttpDateParser is thread safe.
 */
@objc(SentryHttpDateParser) @_spi(Private)
public final class HttpDateParser: NSObject {

    private let dateFormatter: DateFormatter

    public override init() {
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"
        // Http dates are always expressed in GMT, never in local time.
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        super.init()
    }

    @objc(dateFromString:)
    public func date(from string: String) -> Date? {
        return dateFormatter.date(from: string)
    }
}
// swiftlint:enable missing_docs
