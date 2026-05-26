// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCUnit: NSObject {
    private let unit: SentryUnit

    internal init(_ unit: SentryUnit) {
        self.unit = unit
    }

    internal func toSentryUnit() -> SentryUnit {
        unit
    }

    @objc public init(rawValue: String) {
        self.unit = SentryUnit(rawValue: rawValue) ?? .generic(rawValue)
    }

    @objc public var rawValue: String {
        unit.rawValue
    }

    @objc public static var nanosecond: SentryObjCUnit { SentryObjCUnit(.nanosecond) }
    @objc public static var microsecond: SentryObjCUnit { SentryObjCUnit(.microsecond) }
    @objc public static var millisecond: SentryObjCUnit { SentryObjCUnit(.millisecond) }
    @objc public static var second: SentryObjCUnit { SentryObjCUnit(.second) }
    @objc public static var minute: SentryObjCUnit { SentryObjCUnit(.minute) }
    @objc public static var hour: SentryObjCUnit { SentryObjCUnit(.hour) }
    @objc public static var day: SentryObjCUnit { SentryObjCUnit(.day) }
    @objc public static var week: SentryObjCUnit { SentryObjCUnit(.week) }

    @objc public static var bit: SentryObjCUnit { SentryObjCUnit(.bit) }
    @objc public static var byte: SentryObjCUnit { SentryObjCUnit(.byte) }
    @objc public static var kilobyte: SentryObjCUnit { SentryObjCUnit(.kilobyte) }
    @objc public static var kibibyte: SentryObjCUnit { SentryObjCUnit(.kibibyte) }
    @objc public static var megabyte: SentryObjCUnit { SentryObjCUnit(.megabyte) }
    @objc public static var mebibyte: SentryObjCUnit { SentryObjCUnit(.mebibyte) }
    @objc public static var gigabyte: SentryObjCUnit { SentryObjCUnit(.gigabyte) }
    @objc public static var gibibyte: SentryObjCUnit { SentryObjCUnit(.gibibyte) }
    @objc public static var terabyte: SentryObjCUnit { SentryObjCUnit(.terabyte) }
    @objc public static var tebibyte: SentryObjCUnit { SentryObjCUnit(.tebibyte) }
    @objc public static var petabyte: SentryObjCUnit { SentryObjCUnit(.petabyte) }
    @objc public static var pebibyte: SentryObjCUnit { SentryObjCUnit(.pebibyte) }
    @objc public static var exabyte: SentryObjCUnit { SentryObjCUnit(.exabyte) }
    @objc public static var exbibyte: SentryObjCUnit { SentryObjCUnit(.exbibyte) }

    @objc public static var ratio: SentryObjCUnit { SentryObjCUnit(.ratio) }
    @objc public static var percent: SentryObjCUnit { SentryObjCUnit(.percent) }
}

// swiftlint:enable missing_docs
