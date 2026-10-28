#import "SentryProfilerSDKAdapter.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

@interface SentryDefaultProfilerSDKBackend : NSObject <SentryProfilerSDKBackend>
@property (nonatomic, strong) SENTRY_SWIFT_MIGRATION_ID(SentrySystemWrapper) systemWrapper;
- (void)activate;
@end

#    ifdef __cplusplus
extern "C" {
#    endif
void sentry_bootstrapProfilerSDKAdapter(void);
#    ifdef __cplusplus
}
#    endif

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
