#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED && defined(DEBUG)

@class SentrySample;

NS_ASSUME_NONNULL_BEGIN

@interface SentryProfileDebugLoggerHelper : NSObject

+ (uint64_t)getAbsoluteTimeStampFromSample:(SentrySample *)sample;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED && defined(DEBUG)
