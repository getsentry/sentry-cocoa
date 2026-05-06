#import "SentryHub.h"

@class SentryClient;
@class SentryDispatchQueueWrapper;
@class SentryClientInternal;
@protocol SentryCrashReporter;
@protocol SentryIntegrationProtocol;
NS_ASSUME_NONNULL_BEGIN

/** Expose the internal test init for testing. */
@interface SentryHubInternal ()

- (instancetype)initWithClient:(SentryClientInternal *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
               andCrashWrapper:(id<SentryCrashReporter>)crashAdapter
              andDispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

- (NSArray<id<SentryIntegrationProtocol>> *)installedIntegrations;
- (NSSet<NSString *> *)installedIntegrationNames;

- (BOOL)eventContainsOnlyHandledErrors:(NSDictionary *)eventDictionary;
@end

NS_ASSUME_NONNULL_END
