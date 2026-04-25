#import "SentryObjCUnit.h"

NS_ASSUME_NONNULL_BEGIN

SentryObjCUnitName const SentryObjCUnitNameNanosecond = @"nanosecond";
SentryObjCUnitName const SentryObjCUnitNameMicrosecond = @"microsecond";
SentryObjCUnitName const SentryObjCUnitNameMillisecond = @"millisecond";
SentryObjCUnitName const SentryObjCUnitNameSecond = @"second";
SentryObjCUnitName const SentryObjCUnitNameMinute = @"minute";
SentryObjCUnitName const SentryObjCUnitNameHour = @"hour";
SentryObjCUnitName const SentryObjCUnitNameDay = @"day";
SentryObjCUnitName const SentryObjCUnitNameWeek = @"week";
SentryObjCUnitName const SentryObjCUnitNameBit = @"bit";
SentryObjCUnitName const SentryObjCUnitNameByte = @"byte";
SentryObjCUnitName const SentryObjCUnitNameKilobyte = @"kilobyte";
SentryObjCUnitName const SentryObjCUnitNameKibibyte = @"kibibyte";
SentryObjCUnitName const SentryObjCUnitNameMegabyte = @"megabyte";
SentryObjCUnitName const SentryObjCUnitNameMebibyte = @"mebibyte";
SentryObjCUnitName const SentryObjCUnitNameGigabyte = @"gigabyte";
SentryObjCUnitName const SentryObjCUnitNameGibibyte = @"gibibyte";
SentryObjCUnitName const SentryObjCUnitNameTerabyte = @"terabyte";
SentryObjCUnitName const SentryObjCUnitNameTebibyte = @"tebibyte";
SentryObjCUnitName const SentryObjCUnitNamePetabyte = @"petabyte";
SentryObjCUnitName const SentryObjCUnitNamePebibyte = @"pebibyte";
SentryObjCUnitName const SentryObjCUnitNameExabyte = @"exabyte";
SentryObjCUnitName const SentryObjCUnitNameExbibyte = @"exbibyte";
SentryObjCUnitName const SentryObjCUnitNameRatio = @"ratio";
SentryObjCUnitName const SentryObjCUnitNamePercent = @"percent";

SentryObjCUnitName
SentryObjCUnitWithName(NSString *name)
{
    return [name copy];
}

NS_ASSUME_NONNULL_END
