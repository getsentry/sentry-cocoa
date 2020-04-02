#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentrySession.h>
#import <Sentry/SentryInstallation.h>
#import <Sentry/NSDate+SentryExtras.h>
#import "SentryUser.h"
#else
#import "SentrySession.h"
#import "SentryInstallation.h"
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
        _sequence = 1;
        _errors = 0;
        _init = @YES;
    }
    return self;
}

- (void)endSessionWithStatus:(SentrySessionStatus *)status
                   timestamp:(NSDate *)timestamp {
    @synchronized (self) {
        _init = nil;
        _sequence++;

        NSTimeInterval secondsBetween = [_timestamp timeIntervalSinceDate:_started];
        _duration = [NSNumber numberWithLongLong:secondsBetween];

        if (nil != status) {
            _status = *status;
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
        _init = nil;
        _errors++;
        _sequence++;
        _status = kSentrySessionStatusAbnormal;
    }
}

- (NSDictionary<NSString *, id> *)serialize {
    @synchronized (self) {
        NSMutableDictionary *serializedData = @{
                @"sid": _sessionId.UUIDString,
                @"errors": [NSNumber numberWithLong:_errors],
                @"started": [_started sentry_toIso8601String],
        }.mutableCopy;
        
        if (nil != _init) {
            [serializedData setValue:_init forKey:@"init"];
        }
        
        NSString* statusString = nil;
        switch (_status) {
            case kSentrySessionStatusOk:
                statusString = @"ok";
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

        NSDate *timestamp = nil != _timestamp ? _timestamp : [NSDate date];
        [serializedData setValue:[timestamp sentry_toIso8601String] forKey:@"timestamp"];

        if (nil != _duration) {
            [serializedData setValue:_duration forKey:@"duration"];
        } else if (nil == _init) {
            NSTimeInterval secondsBetween = [_timestamp timeIntervalSinceDate:_started];
            [serializedData setValue:[NSNumber numberWithLongLong:secondsBetween] forKey:@"duration"];
        }

        // TODO: seq to be just unix time in mills?
        [serializedData setValue:[NSNumber numberWithLong:_sequence] forKey:@"seq"];

        // TODO: Add the following under `attrs`. Except 'did'
        if (nil != _releaseName || nil != _environment) {
            NSMutableDictionary *attrs = [[NSMutableDictionary alloc] init];
            if (nil != _releaseName) {
                [attrs setValue:_releaseName forKey:@"release"];
            }

            if (nil != _environment) {
                [attrs setValue:_environment forKey:@"environment"];
            }
            [serializedData setValue:attrs forKey:@"attrs"];
        }


        SentryUser *currentUser = _user;
        NSString *did = _distinctId;
        if (nil == did) {
            did = [SentryInstallation id];
        }
//        if (nil != currentUser) {
//            NSString *ipAddress = currentUser.ipAddress;
//            if (nil != ipAddress) {
//                [serializedData setValue:ipAddress forKey:@"ip_address"];
//            }
//            if (nil == did) {
//                if (nil != currentUser.userId) {
//                    did = currentUser.userId;
//                } else if (nil != currentUser.email) {
//                    did == currentUser.email;
//                } else if (nil != currentUser.username) {
//                    did == currentUser.username;
//                }
//            }
//        }

        if (nil != did) {
            [serializedData setValue:did forKey:@"did"];
        }

        return serializedData;
    }
}

@end

NS_ASSUME_NONNULL_END
