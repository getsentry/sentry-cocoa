#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Type-safe units for telemetry data (Metrics, Spans, and Logs).
 *
 * @see https://develop.sentry.dev/sdk/telemetry/attributes/#units
 */
typedef NSString *SentryObjCUnitName NS_STRING_ENUM;

FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameNanosecond;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameMicrosecond;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameMillisecond;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameSecond;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameMinute;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameHour;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameDay;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameWeek;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameBit;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameByte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameKilobyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameKibibyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameMegabyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameMebibyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameGigabyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameGibibyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameTerabyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameTebibyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNamePetabyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNamePebibyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameExabyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameExbibyte;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNameRatio;
FOUNDATION_EXPORT SentryObjCUnitName const SentryObjCUnitNamePercent;

/**
 * Creates a custom unit from a string name.
 *
 * @param name The unit name (e.g. "custom", "request").
 * @return A unit string for use with metrics.
 */
FOUNDATION_EXPORT SentryObjCUnitName SentryObjCUnitWithName(NSString *name);

NS_ASSUME_NONNULL_END
