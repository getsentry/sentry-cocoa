#import "SentryDefines.h"
#import "SentryEvent.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

@interface SentryEvent ()

/**
 * This indicates whether this event is a result of a fatal app termination, such as a crash,
 * watchdog termination or a fatal app hang.
 */
@property (nonatomic) BOOL isFatalEvent;

/**
 * This indicates whether this event describes something that happened in an earlier run of the
 * app, such as a MetricKit diagnostic delivered on a later launch. The client doesn't apply the
 * current scope or the running app's state and mutable device data to such events, because that
 * data describes the current process. Fatal events are always from an earlier run and are
 * identified through @c isFatalEvent instead.
 */
@property (nonatomic) BOOL isFromEarlierAppRun;

#if !SDK_V10
/**
 * This indicates whether this event represents an app hang.
 */
@property (nonatomic, readonly) BOOL isAppHangEvent;
#endif // !SDK_V10

/**
 * We're storing serialized breadcrumbs to disk in JSON, and when we're reading them back (in
 * the case of watchdog termination), we end up with the serialized breadcrumbs again. Instead of
 * turning those dictionaries into proper SentryBreadcrumb instances which then need to be
 * serialized again in SentryEvent, we use this serializedBreadcrumbs property to set the
 * pre-serialized breadcrumbs. It saves a LOT of work - especially turning an NSDictionary into a
 * SentryBreadcrumb is silly when we're just going to do the opposite right after.
 */
@property (nonatomic, strong, nullable) NSArray *serializedBreadcrumbs;

/**
 * Per-call override for attachAllThreads. When non-nil, overrides the value from SentryOptions.
 */
@property (nonatomic, strong, nullable) NSNumber *attachAllThreadsOverride;

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic) uint64_t startSystemTime;
@property (nonatomic) uint64_t endSystemTime;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end
