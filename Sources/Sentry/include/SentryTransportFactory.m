#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryTransportFactory.h>
#import <Sentry/SentryTransport.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentryHttpTransport.h>
#import <Sentry/SentryQueueableRequestManager.h>

#else
#import "SentryTransportInitializer.h"
#import "SentryTransport.h"
#import "SentryOptions.h"
#import "SentryHttpTransport.h"
#import "SentryQueueableRequestManager.h"
#endif

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
        return [[SentryHttpTransport alloc] initWithOptions:options
                                          sentryFileManager:sentryFileManager sentryRequestManager: requestManager];
    }
}

@end

NS_ASSUME_NONNULL_END
