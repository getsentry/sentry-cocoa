#import <Foundation/Foundation.h>

#import "SentryTransport.h"

@class SentryOptions, SentryFileManager;
@protocol SentryCurrentDateProvider;
@protocol SentryRateLimits;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TransportInitializer)
@interface SentryTransportFactory : NSObject

+ (NSArray<id<SentryTransport>> *)initTransports:(SentryOptions *)options
                               sentryFileManager:(SentryFileManager *)sentryFileManager
                                      rateLimits:(id<SentryRateLimits>)rateLimits;

@end

NS_ASSUME_NONNULL_END
