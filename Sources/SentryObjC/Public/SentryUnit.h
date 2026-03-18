#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Type-safe units for telemetry data (Metrics, Spans, and Logs).
 *
 * @see https://develop.sentry.dev/sdk/telemetry/attributes/#units
 */
typedef NSString *SentryUnitName NS_STRING_ENUM;

FOUNDATION_EXPORT SentryUnitName const SentryUnitNameNanosecond;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameMicrosecond;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameMillisecond;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameSecond;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameMinute;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameHour;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameDay;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameWeek;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameBit;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameByte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameKilobyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameKibibyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameMegabyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameMebibyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameGigabyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameGibibyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameTerabyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameTebibyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNamePetabyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNamePebibyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameExabyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameExbibyte;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNameRatio;
FOUNDATION_EXPORT SentryUnitName const SentryUnitNamePercent;

/**
 * Creates a custom unit from a string name.
 *
 * @param name The unit name (e.g. "custom", "request").
 * @return A unit string for use with metrics.
 */
FOUNDATION_EXPORT SentryUnitName SentryUnitWithName(NSString *name);

NS_ASSUME_NONNULL_END
