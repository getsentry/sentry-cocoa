#import "SentrySpanInternal.h"

#import "SentryProfilingConditionals.h"

static NSString *_Nonnull const kSentrySpanStatusSerializationKey = @"status";

@interface SentrySpanInternal ()

#if SENTRY_TARGET_PROFILING_SUPPORTED
@property (copy, nonatomic) NSString *_Nullable profileSessionID;
#endif //  SENTRY_TARGET_PROFILING_SUPPORTED

@end
