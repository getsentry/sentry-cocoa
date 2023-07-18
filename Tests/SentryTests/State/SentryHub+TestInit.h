#import "SentryHub.h"

@class SentryClient;
@class SentryCrashWrapper;

NS_ASSUME_NONNULL_BEGIN

/** Expose the internal test init for testing. */
@interface
SentryHub ()

- (instancetype)initWithClient:(SentryClient *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
               andCrashWrapper:(SentryCrashWrapper *)crashAdapter;

@end

NS_ASSUME_NONNULL_END
