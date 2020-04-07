#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryOptions.h>
#else
#import "SentryEvent.h"
#import "SentryOptions.h"
#endif

@interface SentrySessionTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options;
- (void)start;
@end
