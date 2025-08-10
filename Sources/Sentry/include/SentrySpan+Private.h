#import "SentryProfilingConditionals.h"
#import "SentrySpan.h"
#import "SentrySpanSerializable.h"

@interface SentrySpan () <SentrySpanSerializable>

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (copy, nonatomic) NSString *_Nullable profileSessionID;
#endif //  SENTRY_TARGET_PROFILING_SUPPORTED

@end
