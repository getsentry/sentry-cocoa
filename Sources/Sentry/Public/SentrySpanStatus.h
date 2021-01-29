typedef NS_ENUM(NSUInteger, SentrySpanStatus) {
    /**
     * An undefined status
     */
    kSentrySpanStatusUndefined,
        
    /**
     * The operation completed successfully.
     */
    kSentrySpanStatusOk,
    
    /**
     * Deadline expired before operation could complete.
     */
    kSentrySpanStatusDeadlineExceeded,
    
    /**
     * 401 Unauthorized (actually does mean unauthenticated according to RFC 7235).
     */
    kSentrySpanStatusUnauthenticated,
    
    /**
     * 403 Forbidden
     */
    kSentrySpanStatusPermissionDenied,
    
    /**
     * 404 Not Found. Some requested entity (file or directory) was not found.
     */
    kSentrySpanStatusNotFound,
    
    /**
     * 429 Too Many Requests
     */
    kSentrySpanStatusResourceExhausted,
    
    /**
     * Client specified an invalid argument. 4xx.
     */
    kSentrySpanStatusInvalidArgument,
    
    /**
     * 501 Not Implemented
     */
    kSentrySpanStatusUnimplemented,
    
    /**
     * 503 Service Unavailable
     */
    kSentrySpanStatusUnavailable,
    
    /**
     * Other/generic 5xx.
     */
    kSentrySpanStatusInternalError,
    
    /**
     * Unknown. Any non-standard HTTP status code.
     */
    kSentrySpanStatusUnknownError,
    
    /**
     * The operation was cancelled (typically by the user).
     */
    kSentrySpanStatusCancelled,
    
    /**
     * Already exists (409).
     */
    kSentrySpanStatusAlreadyExists,
    
    /**
     * Operation was rejected because the system is not in a state required for the operation's
     */
    kSentrySpanStatusFailedPrecondition,
    
    /**
     * The operation was aborted, typically due to a concurrency issue.
     */
    kSentrySpanStatusAborted,
    
    /**
     * Operation was attempted past the valid range.
     */
    kSentrySpanStatusOutOfRange,
    
    /**
     * Unrecoverable data loss or corruption
     */
    kSentrySpanStatusDataLoss,
};

static NSString *_Nonnull const SentrySpanStatusNames[] = {
    @"undefined",
    @"ok",
    @"deadline_exceeded",
    @"unauthenticated",
    @"permission_denied",
    @"not_found",
    @"resource_exhausted",
    @"invalid_argument",
    @"unimplemented",
    @"unavailable",
    @"internal_error",
    @"unknown_error",
    @"cancelled",
    @"already_exists",
    @"failed_precondition",
    @"status_aborted",
    @"out_of_range",
    @"data_loss"
};
