// swiftlint:disable missing_docs
import Foundation

@objc
@_spi(Private) public final class SentryDateUtil: NSObject {

    private let currentDateProvider: SentryCurrentDateProvider

    @objc(initWithCurrentDateProvider:)
    public init(currentDateProvider: SentryCurrentDateProvider) {
        self.currentDateProvider = currentDateProvider
        super.init()
    }

    @objc
    public func isInFuture(_ date: Date?) -> Bool {
        guard let date = date else {
            return false
        }

        let currentDate = currentDateProvider.date()
        return currentDate.compare(date) == .orderedAscending
    }

    @objc(getMaximumDate:andOther:)
    public static func getMaximumDate(_ first: Date?, andOther second: Date?) -> Date? {
        guard let first = first else {
            return second
        }
        guard let second = second else {
            return first
        }

        return first.compare(second) == .orderedDescending ? first : second
    }

    @objc
    public static func millisecondsSince1970(_ date: Date) -> Int {
        return Int(date.timeIntervalSince1970 * 1_000)
    }
}
// swiftlint:enable missing_docs
