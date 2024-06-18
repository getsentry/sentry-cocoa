#import "SentryHub.h"

@class SentryClient;
@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@protocol SentryIntegrationProtocol;
NS_ASSUME_NONNULL_BEGIN

/** Expose the internal test init for testing. */
@interface
SentryHub ()

- (instancetype)initWithClient:(SentryClient *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
               andCrashWrapper:(SentryCrashWrapper *)crashAdapter
              andDispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

- (NSArray<id<SentryIntegrationProtocol>> *)installedIntegrations;
- (NSSet<NSString *> *)installedIntegrationNames;

- (BOOL)eventContainsOnlyHandledErrors:(NSDictionary *)eventDictionary;
@end

NS_ASSUME_NONNULL_END
