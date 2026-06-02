#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * @c SentryObjCLogger provides a structured logging interface that captures log entries
 * and sends them to Sentry. Supports multiple log levels (trace, debug, info, warn,
 * error, fatal) and allows attaching arbitrary attributes for enhanced context.
 *
 * @discussion Supported attribute types:
 * - @c NSString, @c NSNumber (boolean, integer, double)
 * - Other types are converted to their string representation
 */
@interface SentryObjCLogger : NSObject
SENTRY_NO_INIT

/// Logs a trace-level message.
- (void)trace:(NSString *)body;
/// Logs a trace-level message with additional attributes.
- (void)trace:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/// Logs a debug-level message.
- (void)debug:(NSString *)body;
/// Logs a debug-level message with additional attributes.
- (void)debug:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/// Logs an info-level message.
- (void)info:(NSString *)body;
/// Logs an info-level message with additional attributes.
- (void)info:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/// Logs a warning-level message.
- (void)warn:(NSString *)body;
/// Logs a warning-level message with additional attributes.
- (void)warn:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/// Logs an error-level message.
- (void)error:(NSString *)body;
/// Logs an error-level message with additional attributes.
- (void)error:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/// Logs a fatal-level message.
- (void)fatal:(NSString *)body;
/// Logs a fatal-level message with additional attributes.
- (void)fatal:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

@end

/**
 * Format string methods for @c SentryObjCLogger.
 *
 * These methods accept Objective-C format strings (@c NSString format specifiers)
 * and automatically capture interpolated values as structured message template attributes
 * (e.g., @c sentry.message.template, @c sentry.message.parameter.0, etc.).
 */
@interface SentryObjCLogger (FormatString)

/// Logs a trace-level message with an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)traceWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
/// Logs a trace-level message with additional attributes and an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)traceWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/// Logs a debug-level message with an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)debugWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
/// Logs a debug-level message with additional attributes and an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)debugWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/// Logs an info-level message with an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)infoWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
/// Logs an info-level message with additional attributes and an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)infoWithAttributes:(NSDictionary<NSString *, id> *)attributes
                    format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/// Logs a warning-level message with an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)warnWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
/// Logs a warning-level message with additional attributes and an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)warnWithAttributes:(NSDictionary<NSString *, id> *)attributes
                    format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/// Logs an error-level message with an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)errorWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
/// Logs an error-level message with additional attributes and an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)errorWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/// Logs a fatal-level message with an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)fatalWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);
/// Logs a fatal-level message with additional attributes and an Objective-C format string.
/// Format specifier values are captured as structured message template attributes.
- (void)fatalWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

@end

NS_ASSUME_NONNULL_END
