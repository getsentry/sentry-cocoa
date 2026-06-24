#import "SentryDefines.h"

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

@interface SentryOptionsHelper : NSObject

+ (nullable SENTRY_SWIFT_MIGRATION_ID(
    SentryOptions))optionsWithDictionary:(NSDictionary<NSString *, id> *)options
                        didFailWithError:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(makeOptions(fromDictionary:));

@end

NS_ASSUME_NONNULL_END
