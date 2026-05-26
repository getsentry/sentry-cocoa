// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

public final class SentryObjCMeasurementUnit: NSObject {
    internal let wrapped: MeasurementUnit

    internal init(_ wrapped: MeasurementUnit) {
        self.wrapped = wrapped
    }

    @objc public init(unit: String) {
        self.wrapped = MeasurementUnit(unit: unit)
    }

    @objc public var unit: String {
        wrapped.unit
    }

    @objc public static var none: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnit.none)
    }

    // MARK: - Duration

    @objc public static var nanosecond: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitDuration.nanosecond)
    }

    @objc public static var microsecond: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitDuration.microsecond)
    }

    @objc public static var millisecond: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitDuration.millisecond)
    }

    @objc public static var second: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitDuration.second)
    }

    @objc public static var minute: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitDuration.minute)
    }

    @objc public static var hour: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitDuration.hour)
    }

    @objc public static var day: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitDuration.day)
    }

    @objc public static var week: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitDuration.week)
    }

    // MARK: - Information

    @objc public static var bit: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.bit)
    }

    @objc public static var byte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.byte)
    }

    @objc public static var kilobyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.kilobyte)
    }

    @objc public static var kibibyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.kibibyte)
    }

    @objc public static var megabyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.megabyte)
    }

    @objc public static var mebibyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.mebibyte)
    }

    @objc public static var gigabyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.gigabyte)
    }

    @objc public static var gibibyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.gibibyte)
    }

    @objc public static var terabyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.terabyte)
    }

    @objc public static var tebibyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.tebibyte)
    }

    @objc public static var petabyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.petabyte)
    }

    @objc public static var pebibyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.pebibyte)
    }

    @objc public static var exabyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.exabyte)
    }

    @objc public static var exbibyte: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitInformation.exbibyte)
    }

    // MARK: - Fraction

    @objc public static var ratio: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitFraction.ratio)
    }

    @objc public static var percent: SentryObjCMeasurementUnit {
        SentryObjCMeasurementUnit(MeasurementUnitFraction.percent)
    }
}

// swiftlint:enable missing_docs
