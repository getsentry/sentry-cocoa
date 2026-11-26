#import "SentryDefines.h"
#import <Foundation/Foundation.h>

@class SentryFileManager;
@class SentryOptions;
@class SentryReachability;
@protocol SentryCurrentDateProvider;
@protocol SentryRateLimits;
@protocol SentryTransport;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TransportInitializer)
@interface SentryTransportFactory : NSObject

+ (NSArray<SENTRY_SWIFT_MIGRATION_ID(id<SentryTransport>)> *)
       initTransports:(SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options
         dateProvider:(SENTRY_SWIFT_MIGRATION_ID(id<SentryCurrentDateProvider>))dateProvider
    sentryFileManager:(SENTRY_SWIFT_MIGRATION_ID(SentryFileManager))sentryFileManager
           rateLimits:(SENTRY_SWIFT_MIGRATION_ID(id<SentryRateLimits>))rateLimits
         reachability:(SENTRY_SWIFT_MIGRATION_ID(SentryReachability))reachability;

@end

NS_ASSUME_NONNULL_END
