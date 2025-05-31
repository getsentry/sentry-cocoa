#include "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryThread;

NS_ASSUME_NONNULL_BEGIN

// Helper function to access C++ in a file that does not import Swift
@interface ThreadInfoHelper : NSObject

+ (SentryThread *)threadInfo;

@end

NS_ASSUME_NONNULL_END

#endif
