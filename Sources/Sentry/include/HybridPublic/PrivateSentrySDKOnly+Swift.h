#import "PrivateSentrySDKOnly.h"

NS_ASSUME_NONNULL_BEGIN

@interface PrivateSentrySDKOnly (Swift)

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * Start a profiler session associated with the given @c SentryId.
 * @return The system time when the profiler session started.
 */
+ (uint64_t)startProfilerForTrace:(SentryId *)traceId;

#endif

#if SENTRY_TARGET_REPLAY_SUPPORTED

/**
 * Return an instance of SentryRedactOptions with given option
 * To be used from SentrySwiftUI, which cannot access the private
 * `SentryRedactOptions` class.
 */
+ (UIView *)sessionReplayMaskingOverlay:(id<SentryRedactOptions>)options;

/**
 * Configure session replay with different breadcrumb converter
 * and screeshot provider. Used by the Hybrid SDKs.
 * Passing nil will keep the previous value.
 */
+ (void)configureSessionReplayWith:(nullable id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
                screenshotProvider:(nullable id<SentryViewScreenshotProvider>)screenshotProvider;

+ (void)captureReplay;
+ (NSString *__nullable)getReplayId;
+ (void)addReplayIgnoreClasses:(NSArray<Class> *_Nonnull)classes;
+ (void)addReplayRedactClasses:(NSArray<Class> *_Nonnull)classes;
+ (void)setIgnoreContainerClass:(Class _Nonnull)containerClass;
+ (void)setRedactContainerClass:(Class _Nonnull)containerClass;
+ (void)setReplayTags:(NSDictionary<NSString *, id> *)tags;

#endif

@end

NS_ASSUME_NONNULL_END
