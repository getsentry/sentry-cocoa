#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentrySession.h>
#import <Sentry/NSDate+SentryExtras.h>
#import "SentryUser.h"

#else
#import "SentrySession.h"
#import "NSDate+SentryExtras.h"
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

- (NSDictionary<NSString *, id> *)serialize {
    if (nil == self.timestamp) {
        self.timestamp = [NSDate date];
    }

    NSMutableDictionary *serializedData = @{
            @"sid": self.sessionId,
            @"errors": [@(*self.errors) stringValue],
            @"timestamp": [self.started sentry_toIso8601String],
    }.mutableCopy;

    NSString* statusString = nil;
    switch (*self.status) {
        case kSentrySessionStatusOk:
            statusString = @"Ok";
            break;
        case kSentrySessionStatusExited:
            statusString = @"exited";
            break;
        case kSentrySessionStatusCrashed:
            statusString = @"crashed";
            break;
        case kSentrySessionStatusAbnormal:
            statusString = @"abnormal";
            break;
        default:
            // TODO: Log warning
            break;
    }
    if (nil != statusString) {
        [serializedData setValue:statusString forKey:@"status"];
    }

    if (nil != self.duration) {
        [serializedData setValue:self.duration forKey:@"duration"];
    }

    if (nil != self.releaseName) {
        [serializedData setValue:self.releaseName forKey:@"release"];
    }

    if (nil != self.environment) {
        [serializedData setValue:self.environment forKey:@"environment"];
    }

    SentryUser *currentUser = self.user;
    NSString *did = self.distinctId;
    if (nil != currentUser) {
        NSString *ipAddress = currentUser.ipAddress;
        if (nil != ipAddress) {
            [serializedData setValue:ipAddress forKey:@"ip_address"];
        }
        if (nil == did) {
            if (nil != currentUser.userId) {
                did = currentUser.userId;
            } else if (nil != currentUser.email) {
                did == currentUser.email;
            } else if (nil != currentUser.username) {
                did == currentUser.username;
            }
        }
    }

    if (nil != did) {
        [serializedData setValue:self.distinctId forKey:@"did"];
    }

    return serializedData;
}

@end

NS_ASSUME_NONNULL_END
