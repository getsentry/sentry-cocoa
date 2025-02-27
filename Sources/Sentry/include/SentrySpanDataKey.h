#import "SentryDefines.h"
#import <Foundation/Foundation.h>

/**
 * Constants for span data field keys.
 *
 * These keys are used to attach additional data to spans in a standardized way.
 *
 * The keys follow [OpenTelemetry's semantic
 * conventions](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/general/trace.md)
 * for attributes and must be:
 * - Lowercase
 * - Use underscores for word separation
 * - Follow the format `<namespace>.<attribute>` (e.g. `file.size`)
 *
 * - Note: See [Sentry SDK development
 * documentation](https://develop.sentry.dev/sdk/telemetry/traces/span-data-conventions/) for more
 * information.
 * - Remark: These constants were originally implemented as a Swift-like enum with associated String
 * values, but due to potential Swift-to-Objective-C interoperability issues (see
 * [GH-4887](https://github.com/getsentry/sentry-cocoa/issues/4887)), they were moved from Swift to
 * Objective-C.
 */
@interface SentrySpanDataKey : NSObject

SENTRY_EXTERN NSString *const SentrySpanDataKeyFileSize;
SENTRY_EXTERN NSString *const SentrySpanDataKeyFilePath;

// For future maintainers:
// Constants defined with `extern` or `SENTRY_EXTERN` are not scoped to the interface and can be
// accessed globally. The following static accessors are for convenience to use the scoped
// accessors, e.g. `SentrySpanDataKey.fileSize`.

@property (class, nonatomic, readonly) NSString *fileSize;
@property (class, nonatomic, readonly) NSString *filePath;

@end
