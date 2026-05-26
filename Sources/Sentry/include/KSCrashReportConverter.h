#import <Foundation/Foundation.h>

@class SentryEvent;
@class SentryInAppLogic;

NS_ASSUME_NONNULL_BEGIN

/**
 * Converts a raw KSCrash crash report dictionary into a @c SentryEvent.
 *
 * This is the KSCrash-flavoured counterpart to @c SentryCrashReportConverter.
 * Key differences from @c SentryCrashReportConverter:
 * - Uses @c KSCrashField_* constants (upstream KSCrash) instead of
 *   @c SentryCrashField_* (our fork).
 * - Reads Sentry scope data from @c report["user"]["sentry_sdk_scope"]
 *   (written there by @c sentry_kscrash_isWritingReportCallback) rather than
 *   from a top-level @c "sentry_sdk_scope" key.
 */
@interface KSCrashReportConverter : NSObject

- (instancetype)initWithReport:(NSDictionary *)report inAppLogic:(SentryInAppLogic *)inAppLogic;

/**
 * Converts the report to a @c SentryEvent.
 * @return The converted event, or @c nil if an error occurred during conversion.
 */
- (nullable SentryEvent *)convertReportToEvent;

@end

NS_ASSUME_NONNULL_END
