#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SENTRY_BAGGAGE_HEADER DEPRECATED_MSG_ATTRIBUTE(
    "Use Baggage.httpHeaderField. This constant will be removed in a future major version.")
    = @"baggage";

static NSString *const SENTRY_TRACE_HEADER DEPRECATED_MSG_ATTRIBUTE(
    "Use TraceHeader.httpHeaderField. This constant will be removed in a future major version.")
    = @"sentry-trace";

static NSString const *SENTRY_TRACE_TYPE DEPRECATED_MSG_ATTRIBUTE(
    "This constant will be removed in a future major version.") = @"trace";

NS_ASSUME_NONNULL_END
