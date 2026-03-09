#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@class SentryAppStartMeasurement;
@class SentryId;

@interface SentryAppStartMeasurementProvider : NSObject

+ (nullable SentryAppStartMeasurement *)
    appStartMeasurementForOperation:(NSString *)operation
                     startTimestamp:(nullable NSDate *)startTimestamp
                profilerReferenceID:(nullable SentryId *)profilerReferenceID;

/**
 * Internal. Only needed for testing.
 */
+ (void)reset;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
