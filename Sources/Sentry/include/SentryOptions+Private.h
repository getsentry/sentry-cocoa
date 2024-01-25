#import "SentryOptions.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentryDefaultEnvironment;

@interface
SentryOptions ()

@property (nullable, nonatomic, copy, readonly) NSNumber *defaultTracesSampleRate;

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nullable, nonatomic, copy, readonly) NSNumber *defaultProfilesSampleRate;
@property (nonatomic, assign) BOOL enableProfiling_DEPRECATED_TEST_ONLY;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

SENTRY_EXTERN BOOL isValidSampleRate(NSNumber *sampleRate);

@end

NS_ASSUME_NONNULL_END
