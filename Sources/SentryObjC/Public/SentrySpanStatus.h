#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Describes the status of the Span/Transaction.
 *
 * @see SentrySpan
 */
typedef NS_ENUM(NSUInteger, SentrySpanStatus) {
    kSentrySpanStatusUndefined,
    kSentrySpanStatusOk,
    kSentrySpanStatusDeadlineExceeded,
    kSentrySpanStatusUnauthenticated,
    kSentrySpanStatusPermissionDenied,
    kSentrySpanStatusNotFound,
    kSentrySpanStatusResourceExhausted,
    kSentrySpanStatusInvalidArgument,
    kSentrySpanStatusUnimplemented,
    kSentrySpanStatusUnavailable,
    kSentrySpanStatusInternalError,
    kSentrySpanStatusUnknownError,
    kSentrySpanStatusCancelled,
    kSentrySpanStatusAlreadyExists,
    kSentrySpanStatusFailedPrecondition,
    kSentrySpanStatusAborted,
    kSentrySpanStatusOutOfRange,
    kSentrySpanStatusDataLoss,
};

FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameUndefined;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameOk;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameDeadlineExceeded;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameUnauthenticated;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNamePermissionDenied;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameNotFound;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameResourceExhausted;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameInvalidArgument;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameUnimplemented;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameUnavailable;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameInternalError;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameUnknownError;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameCancelled;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameAlreadyExists;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameFailedPrecondition;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameAborted;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameOutOfRange;
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameDataLoss;

NSString *nameForSentrySpanStatus(SentrySpanStatus status);

NS_ASSUME_NONNULL_END
