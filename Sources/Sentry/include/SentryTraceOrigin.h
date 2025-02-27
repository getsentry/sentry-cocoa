#import "SentryDefines.h"
#import <Foundation/Foundation.h>

/**
 * Trace origin indicates what created a trace or a span.
 *
 * The origin is of type string and consists of four parts:
 * `<type>.<category>.<integration-name>.<integration-part>`.
 *
 * Only the first is mandatory. The parts build upon each other, meaning it is forbidden to skip one
 * part. For example, you may send parts one and two but aren't allowed to send parts one and three
 * without part two.
 *
 * - Note: See [Sentry SDK development
 * documentation](https://develop.sentry.dev/sdk/telemetry/traces/trace-origin/) for more
 * information.
 * - Remark: Since Objective-C does not have enums with associated string values like Swift, this is
 * implemented as an `NSString` constant list.
 */
@interface SentryTraceOrigin : NSObject

SENTRY_EXTERN NSString *const SentryTraceOriginAutoAppStart;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoAppStartProfile;

SENTRY_EXTERN NSString *const SentryTraceOriginAutoDBCoreData;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoHttpNSURLSession;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoNSData;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoUiEventTracker;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoUITimeToDisplay;
SENTRY_EXTERN NSString *const SentryTraceOriginAutoUIViewController;

SENTRY_EXTERN NSString *const SentryTraceOriginManual;
SENTRY_EXTERN NSString *const SentryTraceOriginManualFileData;
SENTRY_EXTERN NSString *const SentryTraceOriginManualUITimeToDisplay;

// For future maintainers:
// Constants defined with `extern` or `SENTRY_EXTERN` are not scoped to the interface and can be
// accessed globally. The following static accessors are for convenience to use the scoped
// accessors, e.g. `SentryTraceOrigin.autoAppStart`.

@property (class, nonatomic, readonly) NSString *autoAppStart;
@property (class, nonatomic, readonly) NSString *autoAppStartProfile;

@property (class, nonatomic, readonly) NSString *autoDBCoreData;
@property (class, nonatomic, readonly) NSString *autoHttpNSURLSession;
@property (class, nonatomic, readonly) NSString *autoNSData;
@property (class, nonatomic, readonly) NSString *autoUiEventTracker;
@property (class, nonatomic, readonly) NSString *autoUITimeToDisplay;
@property (class, nonatomic, readonly) NSString *autoUIViewController;

@property (class, nonatomic, readonly) NSString *manual;
@property (class, nonatomic, readonly) NSString *manualFileData;
@property (class, nonatomic, readonly) NSString *manualUITimeToDisplay;

@end
