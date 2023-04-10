
#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTracer (Test)

+ (void)resetAppStartMeasurementRead;

- (void)updateStartTime:(NSDate *)startTime;

+ (void)resetConcurrencyTracking;

@end

NS_ASSUME_NONNULL_END
