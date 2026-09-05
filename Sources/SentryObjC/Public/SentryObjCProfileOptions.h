#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#    import "SentryObjCProfileLifecycle.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#    import <SentryObjC/SentryObjCProfileLifecycle.h>
#endif

#if SENTRY_OBJC_PROFILING_SUPPORTED

NS_ASSUME_NONNULL_BEGIN

/// Configuration for the Sentry profiler.
/// @warning Continuous profiling is an experimental feature and may still contain bugs.
/// @note Profiling is automatically disabled if a thread sanitizer is attached.
@interface SentryObjCProfileOptions : NSObject

/// The mode to use for starting and stopping the profiler.
/// @note Default: @c SentryObjCProfileLifecycleManual.
@property (nonatomic) SentryObjCProfileLifecycle lifecycle;

/// The percentage of user sessions in which to enable profiling.
/// @note Default: @c 0.
@property (nonatomic) float sessionSampleRate;

/// Start the profiler as early as possible during the app lifecycle.
/// @note Default: @c NO.
@property (nonatomic) BOOL profileAppStarts;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END

#endif
