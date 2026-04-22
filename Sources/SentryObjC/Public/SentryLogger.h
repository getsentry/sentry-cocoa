#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

// See SentryFeedback.h for an explanation of why SentryObjC's public headers alias
// the plain class name to the Swift-mangled class exported by Sentry.framework.
#if SWIFT_PACKAGE
@class _TtC11SentrySwift12SentryLogger;
@compatibility_alias SentryLogger _TtC11SentrySwift12SentryLogger;
#else
@class _TtC6Sentry12SentryLogger;
@compatibility_alias SentryLogger _TtC6Sentry12SentryLogger;
#endif

/**
 * Structured logging interface that captures log entries and sends them to Sentry.
 *
 * Provides severity-based logging methods. Logs are captured as breadcrumbs
 * or events depending on severity level and SDK configuration.
 *
 * @see SentrySDK
 */
@interface SentryLogger : NSObject

/**
 * Logs a trace-level message.
 *
 * @param body The log message.
 */
- (void)trace:(NSString *)body;

/**
 * Logs a trace-level message with structured attributes.
 *
 * @param body The log message.
 * @param attributes Additional structured data.
 */
- (void)trace:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Logs a debug-level message.
 *
 * @param body The log message.
 */
- (void)debug:(NSString *)body;

/**
 * Logs a debug-level message with structured attributes.
 *
 * @param body The log message.
 * @param attributes Additional structured data.
 */
- (void)debug:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Logs an info-level message.
 *
 * @param body The log message.
 */
- (void)info:(NSString *)body;

/**
 * Logs an info-level message with structured attributes.
 *
 * @param body The log message.
 * @param attributes Additional structured data.
 */
- (void)info:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Logs a warning-level message.
 *
 * @param body The log message.
 */
- (void)warn:(NSString *)body;

/**
 * Logs a warning-level message with structured attributes.
 *
 * @param body The log message.
 * @param attributes Additional structured data.
 */
- (void)warn:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Logs an error-level message.
 *
 * @param body The log message.
 */
- (void)error:(NSString *)body;

/**
 * Logs an error-level message with structured attributes.
 *
 * @param body The log message.
 * @param attributes Additional structured data.
 */
- (void)error:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Logs a fatal-level message.
 *
 * @param body The log message.
 */
- (void)fatal:(NSString *)body;

/**
 * Logs a fatal-level message with structured attributes.
 *
 * @param body The log message.
 * @param attributes Additional structured data.
 */
- (void)fatal:(NSString *)body attributes:(NSDictionary<NSString *, id> *)attributes;

@end

NS_ASSUME_NONNULL_END
