#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
import _SentryPrivate
import SentryObjCInternal
import SentryTestsObjCHelpers
#endif
import Foundation

class HttpDateFormatter {
    static func string(from date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        
        return dateFormatter.string(from: date)
    }
}
