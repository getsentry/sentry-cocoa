#import "SentryUnit.h"

NS_ASSUME_NONNULL_BEGIN

SentryUnitName const SentryUnitNameNanosecond = @"nanosecond";
SentryUnitName const SentryUnitNameMicrosecond = @"microsecond";
SentryUnitName const SentryUnitNameMillisecond = @"millisecond";
SentryUnitName const SentryUnitNameSecond = @"second";
SentryUnitName const SentryUnitNameMinute = @"minute";
SentryUnitName const SentryUnitNameHour = @"hour";
SentryUnitName const SentryUnitNameDay = @"day";
SentryUnitName const SentryUnitNameWeek = @"week";
SentryUnitName const SentryUnitNameBit = @"bit";
SentryUnitName const SentryUnitNameByte = @"byte";
SentryUnitName const SentryUnitNameKilobyte = @"kilobyte";
SentryUnitName const SentryUnitNameKibibyte = @"kibibyte";
SentryUnitName const SentryUnitNameMegabyte = @"megabyte";
SentryUnitName const SentryUnitNameMebibyte = @"mebibyte";
SentryUnitName const SentryUnitNameGigabyte = @"gigabyte";
SentryUnitName const SentryUnitNameGibibyte = @"gibibyte";
SentryUnitName const SentryUnitNameTerabyte = @"terabyte";
SentryUnitName const SentryUnitNameTebibyte = @"tebibyte";
SentryUnitName const SentryUnitNamePetabyte = @"petabyte";
SentryUnitName const SentryUnitNamePebibyte = @"pebibyte";
SentryUnitName const SentryUnitNameExabyte = @"exabyte";
SentryUnitName const SentryUnitNameExbibyte = @"exbibyte";
SentryUnitName const SentryUnitNameRatio = @"ratio";
SentryUnitName const SentryUnitNamePercent = @"percent";

SentryUnitName
SentryUnitWithName(NSString *name)
{
    return [name copy];
}

NS_ASSUME_NONNULL_END
