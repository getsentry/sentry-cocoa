#import <Foundation/Foundation.h>

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
