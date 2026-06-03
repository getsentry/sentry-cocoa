#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * Provides a structured logging interface that captures log entries and sends them to Sentry.
 *
 * @c SentryObjCLogger supports six severity levels—trace, debug, info, warn, error, and
 * fatal—and allows attaching arbitrary key-value attributes for additional context.
 *
 * Obtain the shared logger instance via @c SentryObjCSDK.logger. Do not instantiate this
 * class directly.
 *
 * @discussion
 * <b>Supported attribute value types:</b>
 * @li @c NSString — stored as a string attribute.
 * @li @c NSNumber (boolean, integer, double) — stored with the corresponding typed attribute.
 * @li Other types — converted to their @c -description string.
 *
 * <b>Example:</b>
 * @code
 * SentryObjCLogger *logger = SentryObjCSDK.logger;
 * [logger info:@"User logged in" attributes:@{ @"userId": @"12345" }];
 * [logger error:@"Payment failed" attributes:@{ @"errorCode": @500 }];
 * @endcode
 *
 * @see @c SentryObjCLogger(FormatString) for format-string convenience methods with
 *      automatic message template extraction.
 */
@interface SentryObjCLogger : NSObject
SENTRY_NO_INIT

/**
 * Logs a trace-level message.
 * @param body The log message body.
 */
- (void)trace:(NSString *)body;

/**
 * Logs a trace-level message with additional attributes.
 * @param body       The log message body.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 */
- (void)trace:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Logs a debug-level message.
 * @param body The log message body.
 */
- (void)debug:(NSString *)body;

/**
 * Logs a debug-level message with additional attributes.
 * @param body       The log message body.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 */
- (void)debug:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Logs an info-level message.
 * @param body The log message body.
 */
- (void)info:(NSString *)body;

/**
 * Logs an info-level message with additional attributes.
 * @param body       The log message body.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 */
- (void)info:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Logs a warning-level message.
 * @param body The log message body.
 */
- (void)warn:(NSString *)body;

/**
 * Logs a warning-level message with additional attributes.
 * @param body       The log message body.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 */
- (void)warn:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Logs an error-level message.
 * @param body The log message body.
 */
- (void)error:(NSString *)body;

/**
 * Logs an error-level message with additional attributes.
 * @param body       The log message body.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 */
- (void)error:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Logs a fatal-level message.
 * @param body The log message body.
 */
- (void)fatal:(NSString *)body;

/**
 * Logs a fatal-level message with additional attributes.
 * @param body       The log message body.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 */
- (void)fatal:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

@end

/**
 * Format-string convenience methods for @c SentryObjCLogger.
 *
 * These methods accept @c NSString format strings and variadic arguments, producing a
 * fully formatted log body while automatically extracting structured message template
 * attributes for Sentry's log grouping and search.
 *
 * @discussion
 * For each call the SDK captures:
 * @li @c sentry.message.template — the original format string (e.g., @c
 * "User\ \%\@\ processed\ \%d\ items" ).
 * @li @c sentry.message.parameter.N — each format argument as a typed attribute.
 * @li The log body — the fully interpolated string.
 *
 * <b>Supported format specifiers:</b>
 * @c \%\@ , @c \%d , @c \%i , @c \%u , @c \%x , @c \%X , @c \%o , @c \%f , @c \%F ,
 * @c \%e , @c \%E , @c \%g , @c \%G , @c \%a , @c \%A , @c \%c , @c \%C , @c \%s ,
 * @c \%S , @c \%p , and legacy @c \%D , @c \%O , @c \%U .
 * Length modifiers @c h , @c hh , @c l , @c ll , @c q , @c z , @c t , and @c L are
 * supported. Dynamic width ( @c * ) and precision ( @c .* ) are consumed but not
 * captured as parameters.
 *
 * <b>Example:</b>
 * @code
 * [logger infoWithFormat:@"User %@ processed %d items", userName, count];
 * // body:     "User Alice processed 42 items"
 * // template: "User %@ processed %d items"
 * // parameter.0: "Alice"  (string)
 * // parameter.1: 42       (integer)
 *
 * [logger warnWithAttributes:@{ @"source": @"network" }
 *                     format:@"Request to %@ failed with %d", url, statusCode];
 * @endcode
 *
 * @note Unsupported or unknown specifiers are skipped. Positional format arguments
 *       ( @c \%1$\@ ) are not supported.
 */
@interface SentryObjCLogger (FormatString)

/**
 * Logs a trace-level message with a format string.
 * @param format An @c NSString format string, followed by variadic arguments.
 */
- (void)traceWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/**
 * Logs a trace-level message with additional attributes and a format string.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 * @param format     An @c NSString format string, followed by variadic arguments.
 */
- (void)traceWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 * Logs a debug-level message with a format string.
 * @param format An @c NSString format string, followed by variadic arguments.
 */
- (void)debugWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/**
 * Logs a debug-level message with additional attributes and a format string.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 * @param format     An @c NSString format string, followed by variadic arguments.
 */
- (void)debugWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 * Logs an info-level message with a format string.
 * @param format An @c NSString format string, followed by variadic arguments.
 */
- (void)infoWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/**
 * Logs an info-level message with additional attributes and a format string.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 * @param format     An @c NSString format string, followed by variadic arguments.
 */
- (void)infoWithAttributes:(NSDictionary<NSString *, id> *)attributes
                    format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 * Logs a warning-level message with a format string.
 * @param format An @c NSString format string, followed by variadic arguments.
 */
- (void)warnWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/**
 * Logs a warning-level message with additional attributes and a format string.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 * @param format     An @c NSString format string, followed by variadic arguments.
 */
- (void)warnWithAttributes:(NSDictionary<NSString *, id> *)attributes
                    format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 * Logs an error-level message with a format string.
 * @param format An @c NSString format string, followed by variadic arguments.
 */
- (void)errorWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/**
 * Logs an error-level message with additional attributes and a format string.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 * @param format     An @c NSString format string, followed by variadic arguments.
 */
- (void)errorWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 * Logs a fatal-level message with a format string.
 * @param format An @c NSString format string, followed by variadic arguments.
 */
- (void)fatalWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/**
 * Logs a fatal-level message with additional attributes and a format string.
 * @param attributes A dictionary of key-value pairs attached to the log entry.
 * @param format     An @c NSString format string, followed by variadic arguments.
 */
- (void)fatalWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

@end

NS_ASSUME_NONNULL_END
