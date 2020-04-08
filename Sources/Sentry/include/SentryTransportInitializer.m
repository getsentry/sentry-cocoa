#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryTransportInitializer.h>
#import <Sentry/SentryTransport.h>
#import <Sentry/SentryOptions.h>
#import <Sentry/SentryHttpTransport.h>

#else
#import "SentryTransportInitializer.h"
#import "SentryTransport.h"
#import "SentryOptions.h"
#import "SentryHttpTransport.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryTransportInitializer ()

@end

@implementation SentryTransportInitializer

+ (id<SentryTransport>_Nonnull) initTransport:(SentryOptions *) options
                            sentryFileManager:(SentryFileManager *) sentryFileManager {
    if (nil != options.transport) {
        return options.transport;
    }
    else {
        return [[SentryHttpTransport alloc] initWithOptions:options sentryFileManager:sentryFileManager];
    }
}

@end

NS_ASSUME_NONNULL_END
