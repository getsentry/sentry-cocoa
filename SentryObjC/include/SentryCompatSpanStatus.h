#import <Foundation/Foundation.h>

/// Status of a span/transaction.
typedef NS_ENUM(NSUInteger, SentryCompatSpanStatus) {
    SentryCompatSpanStatusUndefined = 0,
    SentryCompatSpanStatusOk = 1,
    SentryCompatSpanStatusDeadlineExceeded = 2,
    SentryCompatSpanStatusUnauthenticated = 3,
    SentryCompatSpanStatusPermissionDenied = 4,
    SentryCompatSpanStatusNotFound = 5,
    SentryCompatSpanStatusResourceExhausted = 6,
    SentryCompatSpanStatusInvalidArgument = 7,
    SentryCompatSpanStatusUnimplemented = 8,
    SentryCompatSpanStatusUnavailable = 9,
    SentryCompatSpanStatusInternalError = 10,
    SentryCompatSpanStatusUnknownError = 11,
    SentryCompatSpanStatusCancelled = 12,
    SentryCompatSpanStatusAlreadyExists = 13,
    SentryCompatSpanStatusFailedPrecondition = 14,
    SentryCompatSpanStatusAborted = 15,
    SentryCompatSpanStatusOutOfRange = 16,
    SentryCompatSpanStatusDataLoss = 17,
};
