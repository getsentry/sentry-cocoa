#import "SentryCrashIntegration.h"
#import "SentryDispatchQueueWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryCrashIntegration (TestInit)

- (instancetype)initWithCrashWrapper:(SentryCrashWrapper *)crashWrapper
             andDispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

@end

NS_ASSUME_NONNULL_END
