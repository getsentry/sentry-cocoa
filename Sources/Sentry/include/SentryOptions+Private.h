#import "SentryOptions.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentryDefaultEnvironment;

@interface
SentryOptions ()
#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, assign) BOOL enableProfiling_DEPRECATED_TEST_ONLY;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

SENTRY_EXTERN BOOL isValidSampleRate(NSNumber *sampleRate);

@end

NS_ASSUME_NONNULL_END
