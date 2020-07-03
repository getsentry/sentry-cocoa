#import <Foundation/Foundation.h>

#import "SentryCurrentDateProvider.h"
#import "SentryOptions.h"

NS_SWIFT_NAME(SessionTracker)
@interface SentryMacOSSessionTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
            currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider;

- (void)start;
- (void)stop;
@end
