#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * We need to have a standart description for bytes count
 * but NSByteCountFormatter does not allow to choose locale
 * and the result changes according to the device configuration.
 * With our own formatter we can control the result.
 */
@interface SentryByteCountFormatter : SENTRY_BASE_OBJECT

+ (NSString *)bytesCountDescription:(unsigned long)bytes;

@end

NS_ASSUME_NONNULL_END
