#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

typedef void (^SentryProfilingDispatch)(dispatch_block_t block);

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
