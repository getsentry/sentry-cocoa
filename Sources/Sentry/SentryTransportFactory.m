#import <Foundation/Foundation.h>

#import "SentryTransportFactory.h"
#import "SentryTransport.h"
#import "SentryOptions.h"
#import "SentryHttpTransport.h"
#import "SentryQueueableRequestManager.h"
#import "SentryRateLimits.h"
#import "SentryDefaultRateLimits.h"
#import "SentryRetryAfterHeaderParser.h"
#import "SentryHttpDateParser.h"
#import "SentryRateLimitParser.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryTransportFactory ()

@end

@implementation SentryTransportFactory

+ (id<SentryTransport>_Nonnull) initTransport:(SentryOptions *) options
                            sentryFileManager:(SentryFileManager *) sentryFileManager {
    if (nil != options.transport) {
        return options.transport;
    }
    else {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
        id<SentryRequestManager> requestManager = [[SentryQueueableRequestManager alloc] initWithSession:session];
        
        SentryHttpDateParser *httpDateParser = [[SentryHttpDateParser alloc] init];
        SentryRetryAfterHeaderParser * retryAfterHeaderParser = [[SentryRetryAfterHeaderParser alloc] initWithHttpDateParser:httpDateParser];
        SentryRateLimitParser *rateLimitParser = [[SentryRateLimitParser alloc] init];
        id<SentryRateLimits> rateLimits = [[SentryDefaultRateLimits alloc] initWithRetryAfterHeaderParser:retryAfterHeaderParser andRateLimitParser:rateLimitParser];
        
        return [[SentryHttpTransport alloc] initWithOptions:options
                                          sentryFileManager:sentryFileManager sentryRequestManager: requestManager
                                           sentryRateLimits: rateLimits];
    }
}

@end

NS_ASSUME_NONNULL_END
