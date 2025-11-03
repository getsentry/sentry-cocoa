#import "SentrySpan.h"

#import "SentryProfilingConditionals.h"

static NSString *_Nonnull const kSentrySpanStatusSerializationKey = @"status";

@interface SentrySpan ()

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (copy, nonatomic) NSString *_Nullable profileSessionID;
#endif //  SENTRY_TARGET_PROFILING_SUPPORTED

@end
