#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryEvent.h>
#else
#import "SentryEvent.h"
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SentrySessionStatus) {
    kSentrySessionStatusOk = 0,
    kSentrySessionStatusExited = 1,
    kSentrySessionStatusCrashed = 2,
    kSentrySessionStatusAbnormal = 3,
    kSentrySessionStatusDegraded = 4,
};

@interface SentrySession : NSObject

- (instancetype)init NS_DESIGNATED_INITIALIZER;

- (void)close:(SentrySessionStatus)status;

- (void)incrementErrors;

@property(nonatomic, readonly, strong) NSUUID *sessionId;
@property(nonatomic, readonly, strong) NSDate *started;
@property(nonatomic, readonly) enum SentrySessionStatus *status;
@property(nonatomic, readonly) NSInteger *errors;

@property(nonatomic, copy) NSString *_Nullable distinctId;
@property(nonatomic, strong) NSDate *timestamp;
@property(nonatomic, strong) NSNumber *_Nullable duration;
@property(nonatomic, copy) NSString *_Nullable releaseName;
@property(nonatomic, copy) NSString *_Nullable environment;
@property(nonatomic, copy) NSString *_Nullable userAgent;
@property(nonatomic, copy) NSString *_Nullable ipAddress;
@property(nonatomic, copy) NSString *_Nullable user;

@end

NS_ASSUME_NONNULL_END
