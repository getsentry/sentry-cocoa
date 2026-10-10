#import "SentryDefines.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

// As with the client test initializer, erase only Swift-owned types at the Clang boundary.
@interface SentryHubInternal (Test)

- (instancetype)initWithClient:(SentryClientInternal *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
      activeCrashReporterState:(SENTRY_SWIFT_MIGRATION_ID(
                                   id<SentryCrashReporterState>))activeCrashReporterState
              andDispatchQueue:(SENTRY_SWIFT_MIGRATION_ID(SentryDispatchQueueWrapper))dispatchQueue
    NS_SWIFT_NAME(init(testClient:andScope:activeCrashReporterState:andDispatchQueue:));

- (instancetype)initWithClient:(SentryClientInternal *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
      activeCrashReporterState:(SENTRY_SWIFT_MIGRATION_ID(
                                   id<SentryCrashReporterState>))activeCrashReporterState
          scopeContextEnricher:(SENTRY_SWIFT_MIGRATION_ID(
                                   id<SentryScopeContextEnricher>))scopeContextEnricher
              andDispatchQueue:(SENTRY_SWIFT_MIGRATION_ID(SentryDispatchQueueWrapper))dispatchQueue
    NS_SWIFT_NAME(init(testClient:andScope:activeCrashReporterState:scopeContextEnricher:andDispatchQueue:));

- (NSArray *)installedIntegrations;
- (NSSet<NSString *> *)installedIntegrationNames;

- (BOOL)eventContainsOnlyHandledErrors:(NSDictionary *)eventDictionary;
@end

NS_ASSUME_NONNULL_END
