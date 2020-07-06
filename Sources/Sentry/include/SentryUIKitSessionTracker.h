#import <Foundation/Foundation.h>

#import "SentryCurrentDateProvider.h"
#import "SentryEvent.h"
#import "SentryOptions.h"

@interface SentryUIKitSessionTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
            currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider;
- (void)start;
- (void)stop;
@end
