import Foundation

/// An HTTP status code range.
@objc(SentryHttpStatusCodeRange)
open class HttpStatusCodeRange: NSObject {
    private let minValue: Int
    private let maxValue: Int

    /// The minimum HTTP status code.
    @objc open var min: Int { minValue }

    /// The maximum HTTP status code.
    @objc open var max: Int { maxValue }

    /// The HTTP status code min and max.
    ///
    /// The range is inclusive so the min and max is considered part of the range.
    /// For example: 400 to 499; 500 to 599; 400 to 599.
    @objc public init(min: Int, max: Int) {
        minValue = min
        maxValue = max
        super.init()
    }

    /// The HTTP status code.
    ///
    /// For a single status code, for example: 400; 500.
    @objc public init(statusCode: Int) {
        minValue = statusCode
        maxValue = statusCode
        super.init()
    }

    @objc(isInRange:)
    func `is`(inRange statusCode: Int) -> Bool {
        return statusCode >= minValue && statusCode <= maxValue
    }
}
