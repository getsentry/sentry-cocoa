#import "SentryDefines.h"

// App start measurements are only relevant on platforms with UIKit (iOS, tvOS), where
// UIApplicationDidFinishLaunching defines the app start lifecycle.
#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@class SentryAppStartMeasurement;

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
 * Internal. Only needed for testing.
 */
+ (void)reset;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
