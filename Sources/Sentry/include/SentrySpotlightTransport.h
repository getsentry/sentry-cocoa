#import "SentryDefines.h"
#import "SentryRequestManager.h"
#import "SentryTransport.h"

@class SentryDispatchQueueWrapper;
@class SentryNSURLRequestBuilder;
@class SentryOptionsInternal;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySpotlightTransport : NSObject <SentryTransport>
SENTRY_NO_INIT

- (id)initWithOptions:(SentryOptionsInternal *)options
          requestManager:(id<SentryRequestManager>)requestManager
          requestBuilder:(SentryNSURLRequestBuilder *)requestBuilder
    dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

@end

NS_ASSUME_NONNULL_END
