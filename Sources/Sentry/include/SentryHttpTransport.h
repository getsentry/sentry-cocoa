#import "SentryDefines.h"
#import "SentryEnvelopeRateLimit.h"
#import "SentryFileManager.h"
#import "SentryRateLimits.h"
#import "SentryRequestManager.h"
#import "SentryTransport.h"
#import <Foundation/Foundation.h>

@class SentryOptions, SentryDispatchQueueWrapper, SentryDispatchGroupWrapper,
    SentryNSURLRequestBuilder;

NS_ASSUME_NONNULL_BEGIN

@interface SentryHttpTransport
    : NSObject <SentryTransport, SentryEnvelopeRateLimitDelegate, SentryFileManagerDelegate>
SENTRY_NO_INIT

- (id)initWithOptions:(SentryOptions *)options
             fileManager:(SentryFileManager *)fileManager
          requestManager:(id<SentryRequestManager>)requestManager
          requestBuilder:(SentryNSURLRequestBuilder *)requestBuilder
              rateLimits:(id<SentryRateLimits>)rateLimits
       envelopeRateLimit:(SentryEnvelopeRateLimit *)envelopeRateLimit
    dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
    dispatchGroupWrapper:(SentryDispatchGroupWrapper *)dispatchGroupWrapper;

@end

NS_ASSUME_NONNULL_END
