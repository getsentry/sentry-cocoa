#import <Foundation/Foundation.h>

/**
 * Describes the status of the Span/Transaction.
 */
typedef NS_ENUM(NSUInteger, SentrySpanStatus) {
    /**
     * An undefined status.
     */
    kSentrySpanStatusUndefined,

    /**
     * Not an error, returned on success.
     */
    kSentrySpanStatusOk,

    /**
     * The deadline expired before the operation could succeed.
     */
    kSentrySpanStatusDeadlineExceeded,

    /**
     * The requester doesn't have valid authentication credentials for the operation.
     */
    kSentrySpanStatusUnauthenticated,

    /**
     * The caller doesn't have permission to execute the specified operation.
     */
    kSentrySpanStatusPermissionDenied,

    /**
     * Content was not found or request was denied for an entire class of users.
     */
    kSentrySpanStatusNotFound,

    /**
     * The resource has been exhausted e.g. per-user quota exhausted, file system out of space.
     */
    kSentrySpanStatusResourceExhausted,

    /**
     * The client specified an invalid argument.
     */
    kSentrySpanStatusInvalidArgument,

    /**
     * 501 Not Implemented.
     */
    kSentrySpanStatusUnimplemented,

    /**
     * The operation is not implemented or is not supported/enabled for this operation.
     */
    kSentrySpanStatusUnavailable,

    /**
     * Some invariants expected by the underlying system have been broken. This code is reserved for
     * serious errors.
     */
    kSentrySpanStatusInternalError,

    /**
     * An unknown error raised by APIs that don't return enough error information.
     */
    kSentrySpanStatusUnknownError,

    /**
     * The operation was cancelled, typically by the caller.
     */
    kSentrySpanStatusCancelled,

    /**
     * The entity attempted to be created already exists.
     */
    kSentrySpanStatusAlreadyExists,

    /**
     * The client shouldn't retry until the system state has been explicitly handled.
     */
    kSentrySpanStatusFailedPrecondition,

    /**
     * The operation was aborted.
     */
    kSentrySpanStatusAborted,

    /**
     * The operation was attempted past the valid range e.g. seeking past the end of a file.
     */
    kSentrySpanStatusOutOfRange,

    /**
     * Unrecoverable data loss or corruption.
     */
    kSentrySpanStatusDataLoss,
};

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameUndefined DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameOk DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameDeadlineExceeded DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameUnauthenticated DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNamePermissionDenied DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameNotFound DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameResourceExhausted DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameInvalidArgument DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameUnimplemented DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameUnavailable DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameInternalError DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameUnknownError DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameCancelled DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameAlreadyExists DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameFailedPrecondition DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameAborted DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameOutOfRange DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");
FOUNDATION_EXPORT NSString *const kSentrySpanStatusNameDataLoss DEPRECATED_MSG_ATTRIBUTE(
    "Use SentrySpanStatus.name. This constant will be removed in a future major version.");

NSString *nameForSentrySpanStatus(SentrySpanStatus status)
    DEPRECATED_MSG_ATTRIBUTE("Use SentrySpanStatus.name. This function will be removed in a "
                             "future major version.");

NS_ASSUME_NONNULL_END
