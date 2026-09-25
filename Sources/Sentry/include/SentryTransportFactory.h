#import "SentryDefines.h"

@class SentryFileManager;
@class SentryOptions;
@class SentryReachability;
@protocol SentryCurrentDateProvider;
@protocol SentryRateLimits;
@protocol SentryTransport;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TransportInitializer)
@interface SentryTransportFactory : NSObject

+ (NSArray<id<SentryTransport>> *)initTransports:(SentryOptions *)options
                                    dateProvider:(id<SentryCurrentDateProvider>)dateProvider
                               sentryFileManager:(SentryFileManager *)sentryFileManager
                                      rateLimits:(id<SentryRateLimits>)rateLimits
                                    reachability:(SentryReachability *)reachability;

@end

// Swift cannot see this factory's Swift-defined parameter types through the ObjC module.
NSArray *sentry_clientCreateTransports(SENTRY_SWIFT_MIGRATION_ID(SentryOptions) options,
    SENTRY_SWIFT_MIGRATION_ID(id<SentryCurrentDateProvider>) dateProvider,
    SENTRY_SWIFT_MIGRATION_ID(SentryFileManager) fileManager,
    SENTRY_SWIFT_MIGRATION_ID(id<SentryRateLimits>) rateLimits,
    SENTRY_SWIFT_MIGRATION_ID(SentryReachability) reachability);

NS_ASSUME_NONNULL_END
