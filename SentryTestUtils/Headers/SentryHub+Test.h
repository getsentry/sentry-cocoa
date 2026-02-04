#import "SentryHub.h"

@class SentryClient;
@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryClientInternal;
@class IntegrationRegistry;

NS_ASSUME_NONNULL_BEGIN

/** Expose the internal test init for testing. */
@interface SentryHubInternal ()

- (instancetype)initWithClient:(SentryClientInternal *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
               andCrashWrapper:(SentryCrashWrapper *)crashAdapter
              andDispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

@property (nonatomic, readonly, strong) IntegrationRegistry *integrationRegistry;

- (NSSet<NSString *> *)installedIntegrationNames;

- (BOOL)eventContainsOnlyHandledErrors:(NSDictionary *)eventDictionary;
@end

NS_ASSUME_NONNULL_END
