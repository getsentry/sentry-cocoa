#import "SentryDefines.h"

// App start measurements are only relevant on platforms with UIKit (iOS, tvOS), where
// UIApplicationDidFinishLaunching defines the app start lifecycle.
#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@class SentryAppStartMeasurement;
@class SentryId;

/**
 * Provides the app start measurement for attaching to the first UI load transaction.
 *
 * This class still reads the measurement from @c SentrySDKInternal because multiple places in the
 * SDK rely on that storage. Moving storage here would expand the scope of this refactoring; the
 * goal is to extract the measurement-providing logic out of @c SentryTracer to reduce its size.
 */
@interface SentryAppStartMeasurementProvider : NSObject

+ (nullable SentryAppStartMeasurement *)appStartMeasurementForOperation:(NSString *)operation
                                                         startTimestamp:
                                                             (nullable NSDate *)startTimestamp;

/**
 * Marks the app start measurement as read so subsequent calls to
 * @c appStartMeasurementForOperation:startTimestamp: return @c nil.
 * Used by standalone app start transactions that carry their own measurement.
 */
+ (void)markAsRead;

/**
 * Pre-generated trace ID for the app start trace. Set early during SDK init so both
 * the standalone app start transaction and the first UIViewController transaction
 * share the same trace. Returns the stored value without clearing; call @c reset to
 * clear.
 */
+ (void)setAppStartTraceId:(nullable SentryId *)traceId;
+ (nullable SentryId *)appStartTraceId;

/**
 * Stores the name of the first UIViewController rendered during app launch.
 * Used by standalone app start transactions to set the @c app.vitals.start.screen attribute.
 */
+ (void)setAppStartScreen:(nullable NSString *)screenName;
+ (nullable NSString *)consumeAppStartScreen;

/**
 * Internal. Only needed for testing.
 */
+ (void)reset;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
