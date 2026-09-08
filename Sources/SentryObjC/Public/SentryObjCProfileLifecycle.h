#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

#if SENTRY_OBJC_PROFILING_SUPPORTED

/// Different modes for starting and stopping the profiler.
typedef NS_ENUM(NSInteger, SentryObjCProfileLifecycle) {
    /// Profiling is controlled manually with startProfiler/stopProfiler.
    SentryObjCProfileLifecycleManual = 0,
    /// Profiling starts with an active root span and stops when there are none.
    SentryObjCProfileLifecycleTrace
};

#endif
