#import "SentrySpanStatus.h"
#import "SentryDeprecated+Private.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
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
#pragma clang diagnostic pop

NSString *
sentry_spanStatusName(SentrySpanStatus status)
{
    switch (status) {
    case kSentrySpanStatusUndefined:
        return @"undefined";
    case kSentrySpanStatusOk:
        return @"ok";
    case kSentrySpanStatusDeadlineExceeded:
        return @"deadline_exceeded";
    case kSentrySpanStatusUnauthenticated:
        return @"unauthenticated";
    case kSentrySpanStatusPermissionDenied:
        return @"permission_denied";
    case kSentrySpanStatusNotFound:
        return @"not_found";
    case kSentrySpanStatusResourceExhausted:
        return @"resource_exhausted";
    case kSentrySpanStatusInvalidArgument:
        return @"invalid_argument";
    case kSentrySpanStatusUnimplemented:
        return @"unimplemented";
    case kSentrySpanStatusUnavailable:
        return @"unavailable";
    case kSentrySpanStatusInternalError:
        return @"internal_error";
    case kSentrySpanStatusUnknownError:
        return @"unknown_error";
    case kSentrySpanStatusCancelled:
        return @"cancelled";
    case kSentrySpanStatusAlreadyExists:
        return @"already_exists";
    case kSentrySpanStatusFailedPrecondition:
        return @"failed_precondition";
    case kSentrySpanStatusAborted:
        return @"aborted";
    case kSentrySpanStatusOutOfRange:
        return @"out_of_range";
    case kSentrySpanStatusDataLoss:
        return @"data_loss";
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
NSString *
nameForSentrySpanStatus(SentrySpanStatus status)
{
    return sentry_spanStatusName(status);
}
#pragma clang diagnostic pop
