#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentrySession.h>
#else
#import "SentrySession.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentrySession

- (instancetype)init {
    if (self = [super init]) {
        _sessionId = [NSUUID UUID];
        _started = [NSDate date];
        _status = kSentrySessionStatusOk;
        _errors = 0;
    }
    return self;
}

- (void)close:(SentrySessionStatus)status {

}

- (void)incrementErrors {
    @synchronized (self) {
        _errors++;
    }
}

@end

NS_ASSUME_NONNULL_END
