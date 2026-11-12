#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SentryObjCSpanStatus) {
    SentryObjCSpanStatusUndefined = 0,
    SentryObjCSpanStatusOk,
    SentryObjCSpanStatusDeadlineExceeded,
    SentryObjCSpanStatusUnauthenticated,
    SentryObjCSpanStatusPermissionDenied,
    SentryObjCSpanStatusNotFound,
    SentryObjCSpanStatusResourceExhausted,
    SentryObjCSpanStatusInvalidArgument,
    SentryObjCSpanStatusUnimplemented,
    SentryObjCSpanStatusUnavailable,
    SentryObjCSpanStatusInternalError,
    SentryObjCSpanStatusUnknownError,
    SentryObjCSpanStatusCancelled,
    SentryObjCSpanStatusAlreadyExists,
    SentryObjCSpanStatusFailedPrecondition,
    SentryObjCSpanStatusAborted,
    SentryObjCSpanStatusOutOfRange,
    SentryObjCSpanStatusDataLoss
};

/**
 * Provides names for span status values.
 */
@interface SentryObjCSpanStatusName : NSObject
SENTRY_NO_INIT

/// Returns the serialized name for @c status.
+ (NSString *)nameForStatus:(SentryObjCSpanStatus)status;

@end

NS_ASSUME_NONNULL_END
