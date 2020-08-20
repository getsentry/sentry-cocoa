#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryRateLimits.h"
#import "SentryRequestManager.h"
#import "SentryTransport.h"

@class SentryEnvelopeRateLimit, SentryOptions, SentryEvent, SentryFileManager;

NS_ASSUME_NONNULL_BEGIN

@interface SentryHttpTransport : NSObject <SentryTransport>
SENTRY_NO_INIT

- (id)initWithOptions:(SentryOptions *)options
          sentryFileManager:(SentryFileManager *)sentryFileManager
       sentryRequestManager:(id<SentryRequestManager>)sentryRequestManager
           sentryRateLimits:(id<SentryRateLimits>)sentryRateLimits
    sentryEnvelopeRateLimit:(SentryEnvelopeRateLimit *)envelopeRateLimit;

@end

NS_ASSUME_NONNULL_END
