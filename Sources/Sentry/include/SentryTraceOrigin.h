#import "SentryDefines.h"
#import <Foundation/Foundation.h>

/*
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

static NSString *const SentryTraceOriginAutoAppStart = @"auto.app.start";
static NSString *const SentryTraceOriginAutoAppStartProfile = @"auto.app.start.profile";

static NSString *const SentryTraceOriginAutoDBCoreData = @"auto.db.core_data";
static NSString *const SentryTraceOriginAutoHttpNSURLSession = @"auto.http.ns_url_session";
static NSString *const SentryTraceOriginAutoNSData = @"auto.file.ns_data";
static NSString *const SentryTraceOriginAutoUiEventTracker = @"auto.ui.event_tracker";
static NSString *const SentryTraceOriginAutoUITimeToDisplay = @"auto.ui.time_to_display";
static NSString *const SentryTraceOriginAutoUIViewController = @"auto.ui.view_controller";

static NSString *const SentryTraceOriginManual = @"manual";
static NSString *const SentryTraceOriginManualFileData = @"manual.file.data";
static NSString *const SentryTraceOriginManualUITimeToDisplay = @"manual.ui.time_to_display";
