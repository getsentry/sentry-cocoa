#import "SentrySDK.h"

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDK (Private)

+ (void)captureCrashEvent:(SentryEvent *)event;

@property (nonatomic, class) BOOL crashedLastRunCalled;

@end

NS_ASSUME_NONNULL_END
