#import "SentrySDK.h"

@class SentryId, SentryAttachment;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDK (Private)

+ (void)captureCrashEvent:(SentryEvent *)event
              attachments:(NSArray<SentryAttachment *> *)attachments;

/**
 * SDK private field to store the state if onCrashedLastRun was called.
 */
@property (nonatomic, class) BOOL crashedLastRunCalled;

@end

NS_ASSUME_NONNULL_END
