#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentrySession.h>
#import <Sentry/NSDate+SentryExtras.h>
#import "SentryUser.h"
#else
#import "SentrySession.h"
#import "NSDate+SentryExtras.h"
#import "SentryUser.h"
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

- (void)endSessionWithStatus:(SentrySessionStatus *)status
                   timestamp:(NSDate *)timestamp {
    @synchronized (self) {
        _init = nil;

        if (nil == timestamp) {
            _timestamp = [NSDate date];
        } else {
            _timestamp = timestamp;
        }

        NSTimeInterval secondsBetween = [_timestamp timeIntervalSinceDate:_started];
        _duration = [NSNumber numberWithLongLong:secondsBetween];

        if (nil != status) {
            _status = status;
        } else if (_status == kSentrySessionStatusOk) {
            // From star to end no state transition (i.e: no errors).
            _status = kSentrySessionStatusExited;
        } else {
            // State transition should be changed by the methods in this object or explicitly passed.
            _status = kSentrySessionStatusAbnormal;
        };
    }
}

- (void)incrementErrors {
    @synchronized (self) {
        _errors++;
        _status = kSentrySessionStatusAbnormal;
    }
}

- (NSDictionary<NSString *, id> *)serialize {
    @synchronized (self) {
        NSMutableDictionary *serializedData = @{
                @"sid": _sessionId,
                @"errors": [@(*_errors) stringValue],
                @"started": [_started sentry_toIso8601String],
        }.mutableCopy;

        NSString* statusString = nil;
        switch (_status) {
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

        if (nil != _timestamp) {
            [serializedData setValue:[_timestamp sentry_toIso8601String] forKey:@"timestamp"];
        }

        if (nil != _init) {
            [serializedData setValue:_init forKey:@"init"];
        }

        if (nil != _duration) {
            NSNumber *duration = [NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970] * 1000];
            [serializedData setValue:duration forKey:@"duration"];
        }

        if (nil != _sequence) {
            [serializedData setValue:[@(*_sequence) stringValue] forKey:@"seq"];
        }

        // TODO: Add the following under `attrs`. Except 'did'
        if (nil != _releaseName) {
            [serializedData setValue:_releaseName forKey:@"release"];
        }

        if (nil != _environment) {
            [serializedData setValue:_environment forKey:@"environment"];
        }

        SentryUser *currentUser = _user;
        NSString *did = _distinctId;
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
            [serializedData setValue:_distinctId forKey:@"did"];
        }

        return serializedData;
    }
}

@end

NS_ASSUME_NONNULL_END
