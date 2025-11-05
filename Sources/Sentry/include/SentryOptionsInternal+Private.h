#if __has_include(<Sentry/SentryOptionsInternal.h>)
#    import <Sentry/SentryOptionsInternal.h>
#else
#    import "SentryOptionsInternal.h"
#endif

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSentryDefaultEnvironment;

@interface SentryOptionsInternal ()
#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (nonatomic, assign) BOOL enableProfiling_DEPRECATED_TEST_ONLY;

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

NS_ASSUME_NONNULL_END
