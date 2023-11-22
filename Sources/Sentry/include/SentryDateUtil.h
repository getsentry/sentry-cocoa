#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(DateUtil)
@interface SentryDateUtil : SENTRY_BASE_OBJECT

+ (BOOL)isInFuture:(NSDate *_Nullable)date;

+ (NSDate *_Nullable)getMaximumDate:(NSDate *_Nullable)first andOther:(NSDate *_Nullable)second;

@end

NS_ASSUME_NONNULL_END
