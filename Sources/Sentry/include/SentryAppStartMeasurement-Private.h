#import "SentryAppStartMeasurement.h"

@interface SentryAppStartMeasurement (SentryPrivate)

@property (nonatomic, assign) uint64_t appStartSystemTime;
@property (nonatomic, assign) uint64_t runtimeInitSystemTime;
@property (nonatomic, assign) uint64_t moduleInitializationSystemTime;
@property (nonatomic, assign) uint64_t didFinishLaunchingSystemTime;

@end
