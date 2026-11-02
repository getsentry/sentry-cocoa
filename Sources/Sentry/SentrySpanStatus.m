#import "SentrySpanStatus.h"
#import "SentryDeprecated+Private.h"

// Deprecated public symbols. Internal callers use sentry_spanStatusName, whose
// values are defined by SentrySpanStatus.name.
NSString *const kSentrySpanStatusNameUndefined = @"undefined";
NSString *const kSentrySpanStatusNameOk = @"ok";
NSString *const kSentrySpanStatusNameDeadlineExceeded = @"deadline_exceeded";
NSString *const kSentrySpanStatusNameUnauthenticated = @"unauthenticated";
NSString *const kSentrySpanStatusNamePermissionDenied = @"permission_denied";
NSString *const kSentrySpanStatusNameNotFound = @"not_found";
NSString *const kSentrySpanStatusNameResourceExhausted = @"resource_exhausted";
NSString *const kSentrySpanStatusNameInvalidArgument = @"invalid_argument";
NSString *const kSentrySpanStatusNameUnimplemented = @"unimplemented";
NSString *const kSentrySpanStatusNameUnavailable = @"unavailable";
NSString *const kSentrySpanStatusNameInternalError = @"internal_error";
NSString *const kSentrySpanStatusNameUnknownError = @"unknown_error";
NSString *const kSentrySpanStatusNameCancelled = @"cancelled";
NSString *const kSentrySpanStatusNameAlreadyExists = @"already_exists";
NSString *const kSentrySpanStatusNameFailedPrecondition = @"failed_precondition";
NSString *const kSentrySpanStatusNameAborted = @"aborted";
NSString *const kSentrySpanStatusNameOutOfRange = @"out_of_range";
NSString *const kSentrySpanStatusNameDataLoss = @"data_loss";

NSString *
nameForSentrySpanStatus(SentrySpanStatus status)
{
    return sentry_spanStatusName(status);
}
