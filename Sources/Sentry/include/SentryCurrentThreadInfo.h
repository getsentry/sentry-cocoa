#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import <Foundation/Foundation.h>

@class SentryThread;

// +[SentryThread threadInfo] lives on a class extension whose header imports the
// public thread type, so Swift calls this instead.
FOUNDATION_EXPORT SentryThread *_Nonnull sentry_currentThreadInfo(void);
#endif
