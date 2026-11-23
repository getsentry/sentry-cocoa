#import "SentryProfilerSDKAdapter.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@interface SentryDefaultProfilerSDKBackend : NSObject <SentryProfilerSDKBackend>
#    if defined(DEBUG) // Test support.
@property (nonatomic, strong) SENTRY_SWIFT_MIGRATION_ID(SentrySystemWrapper) systemWrapper;
#    endif
- (void)activate;
@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
