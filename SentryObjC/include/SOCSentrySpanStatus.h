#import <Foundation/Foundation.h>

/// Status of a span/transaction.
typedef NS_ENUM(NSUInteger, SOCSentrySpanStatus) {
    SOCSentrySpanStatusUndefined = 0,
    SOCSentrySpanStatusOk = 1,
    SOCSentrySpanStatusDeadlineExceeded = 2,
    SOCSentrySpanStatusUnauthenticated = 3,
    SOCSentrySpanStatusPermissionDenied = 4,
    SOCSentrySpanStatusNotFound = 5,
    SOCSentrySpanStatusResourceExhausted = 6,
    SOCSentrySpanStatusInvalidArgument = 7,
    SOCSentrySpanStatusUnimplemented = 8,
    SOCSentrySpanStatusUnavailable = 9,
    SOCSentrySpanStatusInternalError = 10,
    SOCSentrySpanStatusUnknownError = 11,
    SOCSentrySpanStatusCancelled = 12,
    SOCSentrySpanStatusAlreadyExists = 13,
    SOCSentrySpanStatusFailedPrecondition = 14,
    SOCSentrySpanStatusAborted = 15,
    SOCSentrySpanStatusOutOfRange = 16,
    SOCSentrySpanStatusDataLoss = 17,
};
