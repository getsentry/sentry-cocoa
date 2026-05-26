#import <Foundation/Foundation.h>

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

NS_ASSUME_NONNULL_END
