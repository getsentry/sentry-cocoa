#import "SentryDefines.h"
#import <Foundation/Foundation.h>

/*
 * Span operations are short string identifiers that categorize the type of operation a span is
 * measuring.
 *
 * They follow a hierarchical dot notation format (e.g., `ui.load.initial_display`) to group related
 * operations. These identifiers help organize and analyze performance data across different types
 * of operations.
 *
 * - Note: See [Sentry SDK development
 * documentation](https://develop.sentry.dev/sdk/telemetry/traces/span-operations/) for more
 * information.
 * - Remark: These constants were originally implemented as a Swift-like enum with associated String
 * values, but due to potential Swift-to-Objective-C interoperability issues (see
 * [GH-4887](https://github.com/getsentry/sentry-cocoa/issues/4887)), they were moved from Swift to
 * Objective-C.
 */

static NSString *const SentrySpanOperationAppLifecycle = @"app.lifecycle";

static NSString *const SentrySpanOperationCoredataFetchOperation = @"db.sql.query";
static NSString *const SentrySpanOperationCoredataSaveOperation = @"db.sql.transaction";

static NSString *const SentrySpanOperationFileRead = @"file.read";
static NSString *const SentrySpanOperationFileWrite = @"file.write";
static NSString *const SentrySpanOperationFileCopy = @"file.copy";
static NSString *const SentrySpanOperationFileRename = @"file.rename";
static NSString *const SentrySpanOperationFileDelete = @"file.delete";

static NSString *const SentrySpanOperationNetworkRequestOperation = @"http.client";

static NSString *const SentrySpanOperationUiAction = @"ui.action";
static NSString *const SentrySpanOperationUiActionClick = @"ui.action.click";

// Note: The operation is used by the is marked as `SENTRY_EXTERN` to resolve this compilation error
// of the SentryProfilerTests: `Undefined symbol: _SentrySpanOperationUiLoad`
SENTRY_EXTERN NSString *const SentrySpanOperationUiLoad;

static NSString *const SentrySpanOperationUiLoadInitialDisplay = @"ui.load.initial_display";
static NSString *const SentrySpanOperationUiLoadFullDisplay = @"ui.load.full_display";
